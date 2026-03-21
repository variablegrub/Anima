import Foundation
import Combine

enum SessionState {
    case disconnected
    case idle
    case listening
    case thinking
    case speaking
}

@MainActor
class SessionViewModel: ObservableObject {
    @Published var state: SessionState = .disconnected
    @Published var transcript: [TranscriptMessage] = []
    @Published var currentTranscription: String = ""
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?

    @Published var config: ClaudeConfig {
        didSet { bridge = ClaudeBridge(config: config) }
    }

    // Frame sources
    @Published var activeFrameSource: FrameSourceType = .iPhone {
        didSet { switchFrameSource() }
    }
    @Published var frameSourceStatus: FrameSourceStatus = .disconnected

    private var bridge: ClaudeBridge
    let speechManager = SpeechManager()
    let cameraManager = CameraManager()
    let rayBanManager = RayBanManager()
    private var cancellables = Set<AnyCancellable>()

    /// The currently active frame source
    var currentFrameSource: any FrameSource {
        switch activeFrameSource {
        case .iPhone: return cameraManager
        case .rayBan: return rayBanManager
        }
    }

    init(config: ClaudeConfig = ClaudeConfig()) {
        self.config = config
        self.bridge = ClaudeBridge(config: config)
        setupBindings()
    }

    private func setupBindings() {
        // Mirror speech transcription to our published property
        speechManager.$transcribedText
            .receive(on: RunLoop.main)
            .assign(to: &$currentTranscription)

        // Handle speech pauses — this is where the magic happens
        speechManager.onSpeechPause = { [weak self] text in
            Task { @MainActor in
                await self?.handleUserSpeech(text)
            }
        }

        speechManager.setPauseThreshold(config.speechPauseThreshold)

        // Handle audio interruptions
        NotificationCenter.default.publisher(for: .audioInterruptionBegan)
            .sink { [weak self] _ in
                self?.speechManager.stopListening()
                self?.speechManager.stopSpeaking()
                self?.state = .idle
            }
            .store(in: &cancellables)
    }

    // MARK: - Frame Source Switching

    private func switchFrameSource() {
        // Stop current source
        cameraManager.stop()
        rayBanManager.stop()

        // Start new source
        do {
            let source = currentFrameSource
            source.configure(
                frameInterval: config.videoFrameInterval,
                jpegQuality: config.videoJPEGQuality
            )
            try source.start()
            frameSourceStatus = .connected
            errorMessage = nil
        } catch {
            frameSourceStatus = .error(error.localizedDescription)
            errorMessage = error.localizedDescription

            // Fall back to iPhone camera if Ray-Ban fails
            if activeFrameSource == .rayBan {
                errorMessage = "\(error.localizedDescription)\nFalling back to iPhone camera."
                activeFrameSource = .iPhone
            }
        }
    }

    // MARK: - Connection

    func connect() async {
        do {
            let health = try await bridge.checkHealth()
            if health.status == "ok" {
                isConnected = true
                state = .idle
                errorMessage = nil

                // Setup audio
                try AudioSessionManager.shared.configureForVoiceChat()

                // Start the active frame source
                let source = currentFrameSource
                source.configure(
                    frameInterval: config.videoFrameInterval,
                    jpegQuality: config.videoJPEGQuality
                )
                try source.start()
                frameSourceStatus = .connected
            }
        } catch {
            errorMessage = "Cannot connect to gateway: \(error.localizedDescription)"
            state = .disconnected
            isConnected = false
        }
    }

    func disconnect() {
        speechManager.stopListening()
        speechManager.stopSpeaking()
        cameraManager.stop()
        rayBanManager.stop()
        frameSourceStatus = .disconnected
        state = .disconnected
        isConnected = false
    }

    // MARK: - Voice Interaction

    func toggleListening() {
        if speechManager.isListening {
            speechManager.stopListening()
            state = .idle
        } else {
            startListening()
        }
    }

    func startListening() {
        // Interrupt TTS if speaking
        if speechManager.isSpeaking {
            speechManager.stopSpeaking()
        }

        do {
            try speechManager.startListening()
            state = .listening
            errorMessage = nil
        } catch {
            errorMessage = "Could not start listening: \(error.localizedDescription)"
        }
    }

    // MARK: - Send to Claude

    private func handleUserSpeech(_ text: String) async {
        // Add user message to transcript
        transcript.append(TranscriptMessage(role: .user, text: text))
        currentTranscription = ""
        state = .thinking

        // Grab latest camera frame from active source
        var images: [Data] = []
        if let frame = currentFrameSource.consumeFrame() {
            images.append(frame)
        }

        do {
            let response = try await bridge.chat(text: text, images: images)

            // Add assistant response to transcript
            transcript.append(TranscriptMessage(
                role: .assistant,
                text: response.text,
                toolCalls: response.tool_calls
            ))

            // Speak the response
            state = .speaking
            speechManager.speak(response.text)

            // When speech finishes, go back to listening
            observeSpeechCompletion()

        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            state = .idle
        }
    }

    private func observeSpeechCompletion() {
        // Watch for TTS completion, then auto-listen again
        speechManager.$isSpeaking
            .dropFirst()
            .filter { !$0 }
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isConnected, self.state == .speaking else { return }
                self.startListening()
            }
            .store(in: &cancellables)
    }

    // MARK: - Manual Text Input

    func sendText(_ text: String) async {
        guard !text.isEmpty else { return }
        await handleUserSpeech(text)
    }

    func resetConversation() async {
        transcript.removeAll()
        await bridge.resetConversation()
    }
}

// MARK: - FrameSource configure extension

@MainActor
private extension FrameSource {
    func configure(frameInterval: TimeInterval, jpegQuality: CGFloat) {
        if let cam = self as? CameraManager {
            cam.configure(frameInterval: frameInterval, jpegQuality: jpegQuality)
        } else if let rb = self as? RayBanManager {
            rb.configure(frameInterval: frameInterval, jpegQuality: jpegQuality)
        }
    }
}
