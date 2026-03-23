import SwiftUI

struct SettingsView: View {
    @Binding var config: ClaudeConfig
    @Binding var activeFrameSource: FrameSourceType
    let isConnected: Bool
    let frameSourceStatus: FrameSourceStatus
    let rayBanManager: RayBanManager
    let onConnect: () -> Void
    let onConnectGlasses: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showRayBanInstructions = false

    // Anthropic brand accent
    private let accentColor = Color(red: 232/255, green: 123/255, blue: 53/255)

    var body: some View {
        NavigationStack {
            List {
                // ── Connection Status ──
                connectionStatusSection

                // ── Server Settings ──
                serverSection

                // ── Camera Source ──
                cameraSection

                // ── Meta Ray-Ban Glasses ──
                rayBanSection

                // ── Voice & Speech ──
                voiceSection

                // ── ElevenLabs ──
                elevenLabsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .tint(accentColor)
            .sheet(isPresented: $showRayBanInstructions) {
                RayBanInstructionsView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onConnect()
                        dismiss()
                    } label: {
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Connection Status

    private var connectionStatusSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isConnected ? .green.opacity(0.15) : .red.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isConnected ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                    Text(isConnected ? "Gateway is reachable" : "Tap Connect to establish a session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(isConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                    .shadow(color: isConnected ? .green.opacity(0.5) : .clear, radius: 4)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Server Settings

    private var serverSection: some View {
        Section {
            HStack(spacing: 14) {
                settingIcon("server.rack", color: .blue)
                Text("Host")
                Spacer()
                TextField("hostname.local", text: $config.gatewayHost)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                settingIcon("number", color: .blue)
                Text("Port")
                Spacer()
                TextField("18790", text: Binding(
                    get: { String(config.gatewayPort) },
                    set: { config.gatewayPort = Int($0) ?? 18790 }
                ))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                settingIcon("key.fill", color: .blue)
                Text("Channel Token")
                Spacer()
                SecureField("paste token", text: $config.channelToken)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            // Test Connection Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                testConnection()
            } label: {
                HStack(spacing: 14) {
                    settingIcon("bolt.horizontal.circle.fill", color: accentColor)

                    Text("Test Connection")
                        .foregroundStyle(.primary)

                    Spacer()

                    if isTesting {
                        ProgressView()
                            .tint(accentColor)
                    } else if let result = testResult {
                        HStack(spacing: 4) {
                            Image(systemName: result.contains("OK") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.contains("OK") ? .green : .red)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.contains("OK") ? .green : .red)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Label("Gateway Connection", systemImage: "network")
                .textCase(nil)
                .font(.subheadline.weight(.semibold))
        } footer: {
            Text("Enter the address of your VisionClaude gateway server. The channel token enables direct Claude Code integration.")
        }
    }

    // MARK: - Camera Source

    private var cameraSection: some View {
        Section {
            Picker("Source", selection: $activeFrameSource) {
                ForEach(FrameSourceType.allCases) { source in
                    Label(source.rawValue, systemImage: source.icon)
                        .tag(source)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            HStack(spacing: 14) {
                settingIcon("camera.badge.ellipsis", color: .purple)
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(frameStatusDotColor)
                        .frame(width: 8, height: 8)
                    Text(frameSourceStatus.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    settingIcon("timer", color: .purple)
                    Text("Frame Interval")
                    Spacer()
                    Text("\(config.videoFrameInterval, specifier: "%.1f")s")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.videoFrameInterval, in: 0.5...5.0, step: 0.5)
                    .tint(accentColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    settingIcon("photo.badge.checkmark", color: .purple)
                    Text("JPEG Quality")
                    Spacer()
                    Text("\(Int(config.videoJPEGQuality * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.videoJPEGQuality, in: 0.1...1.0, step: 0.1)
                    .tint(accentColor)
            }
        } header: {
            Label("Camera Source", systemImage: "camera")
                .textCase(nil)
                .font(.subheadline.weight(.semibold))
        } footer: {
            Text("Choose between the iPhone camera or Meta Ray-Ban glasses for the video feed. Adjust capture rate and quality to balance performance.")
        }
    }

    // MARK: - Ray-Ban Section

    private var rayBanSection: some View {
        Section {
            // Device row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rayBanManager.glassesName)
                        .font(.body)
                    if activeFrameSource == .rayBan {
                        Text("Stream: \(frameSourceStatus.label)")
                            .font(.caption)
                            .foregroundStyle(frameSourceStatus.isConnected ? .green : accentColor)
                    }
                }

                Spacer()

                if rayBanManager.hasActiveDevice {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Paired")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 2)

            // Registration status
            HStack(spacing: 14) {
                settingIcon("person.badge.key", color: .mint)
                Text("Registration")
                Spacer()
                Text(rayBanManager.isRegistered ? "Registered" : "Not Registered")
                    .font(.subheadline)
                    .foregroundStyle(rayBanManager.isRegistered ? .green : accentColor)
            }

            // Connect button
            if !rayBanManager.isRegistered {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onConnectGlasses()
                } label: {
                    HStack(spacing: 14) {
                        settingIcon("link.circle.fill", color: accentColor)
                        Text("Connect Glasses via Meta AI")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Setup instructions
            Button {
                showRayBanInstructions = true
            } label: {
                HStack(spacing: 14) {
                    settingIcon("book.closed.fill", color: .indigo)
                    Text("Setup Instructions")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Meta Ray-Ban Glasses", systemImage: "eyeglasses")
                .textCase(nil)
                .font(.subheadline.weight(.semibold))
        } footer: {
            if activeFrameSource == .rayBan && !frameSourceStatus.isConnected {
                if !rayBanManager.isRegistered {
                    Text("Tap 'Connect Glasses via Meta AI' to register. This will open the Meta AI app for approval.")
                } else {
                    Text("Registered but stream not active. Make sure glasses are powered on with hinges open, and Developer Mode is enabled.")
                }
            } else {
                Text("Pair your Meta Ray-Ban smart glasses to use their camera as a live video source.")
            }
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    settingIcon("waveform", color: .green)
                    Text("Pause Threshold")
                    Spacer()
                    Text("\(config.speechPauseThreshold, specifier: "%.1f")s")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.speechPauseThreshold, in: 0.5...3.0, step: 0.5)
                    .tint(accentColor)
            }

            HStack(spacing: 14) {
                settingIcon("speaker.wave.3.fill", color: .green)
                Text("TTS Provider")
                Spacer()
                Text(config.elevenLabsAPIKey.isEmpty ? "Apple (Basic)" : "ElevenLabs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary, in: Capsule())
            }
        } header: {
            Label("Voice & Speech", systemImage: "mic.circle")
                .textCase(nil)
                .font(.subheadline.weight(.semibold))
        } footer: {
            Text("Controls how long VisionClaude waits after you stop speaking before sending your message. Lower values feel snappier.")
        }
    }

    // MARK: - ElevenLabs Section

    private var elevenLabsSection: some View {
        Section {
            HStack(spacing: 14) {
                settingIcon("key.fill", color: .cyan)
                Text("API Key")
                Spacer()
                SecureField("ElevenLabs API key", text: $config.elevenLabsAPIKey)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !config.elevenLabsAPIKey.isEmpty {
                let selectedVoice = ElevenLabsVoice.voice(for: config.elevenLabsVoiceId)

                // Voice picker (Navigation-style for better UX)
                Picker(selection: $config.elevenLabsVoiceId) {
                    ForEach(ElevenLabsVoice.allVoices) { voice in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .font(.body)
                                Text(voice.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(voice.id)
                    }
                } label: {
                    HStack(spacing: 14) {
                        settingIcon("person.wave.2.fill", color: .cyan)
                        Text("Voice")
                        Spacer()
                        Text(selectedVoice.name)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: config.elevenLabsVoiceId) { _, newValue in
                    let voice = ElevenLabsVoice.voice(for: newValue)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    print("[Settings] Voice changed to: \(voice.name)")
                }
            }
        } header: {
            Label("ElevenLabs TTS", systemImage: "waveform.circle")
                .textCase(nil)
                .font(.subheadline.weight(.semibold))
        } footer: {
            Text("Add an ElevenLabs API key to unlock premium text-to-speech voices with natural intonation.")
        }
    }

    // MARK: - Helpers

    private func settingIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private var frameStatusDotColor: Color {
        switch frameSourceStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        default: return .gray
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let bridge = ClaudeBridge(config: config)
                let health = try await bridge.checkHealth()
                testResult = "OK (\(health.status))"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                testResult = "Failed"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isTesting = false
        }
    }
}

// MARK: - Ray-Ban Setup Instructions Sheet

struct RayBanInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    private let accentColor = Color(red: 232/255, green: 123/255, blue: 53/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: "eyeglasses")
                                .font(.system(size: 28))
                                .foregroundStyle(accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Meta Ray-Ban Setup")
                                .font(.title2.bold())
                            Text("Developer Mode Configuration")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 4)

                    Divider()

                    // Prerequisites
                    sectionHeader("Prerequisites", icon: "checkmark.circle")
                    bulletPoint("Meta Ray-Ban Smart Glasses or Ray-Ban Display glasses")
                    bulletPoint("Meta AI app installed on this iPhone")
                    bulletPoint("Glasses paired and connected via Meta AI app")
                    linkButton("Download Meta AI App", url: "https://apps.apple.com/app/meta-ai/id1662457680")

                    Divider()

                    // Step-by-step
                    sectionHeader("Step 1: Pair Your Glasses", icon: "wave.3.right")
                    stepView(1, "Open the Meta AI app on your iPhone")
                    stepView(2, "Sign in with your Meta account")
                    stepView(3, "Follow the in-app pairing flow to connect your glasses via Bluetooth")
                    stepView(4, "Make sure glasses are fully updated (Meta AI app will prompt if needed)")

                    Divider()

                    sectionHeader("Step 2: Enable Developer Mode", icon: "wrench.and.screwdriver")
                    stepView(5, "In the Meta AI app, go to:\nSettings → Your glasses → Developer Mode")
                    stepView(6, "Toggle Developer Mode ON")
                    stepView(7, "Restart your glasses:\n• Hold the button for 15 seconds to power off\n• Press the button to power back on")

                    Divider()

                    sectionHeader("Step 3: Connect in VisionClaude", icon: "eyeglasses")
                    stepView(8, "Return to VisionClaude")
                    stepView(9, "Go to Settings → Camera Source → select Meta Ray-Ban")
                    stepView(10, "Tap \"Connect\" — VisionClaude will register with Meta AI")
                    stepView(11, "You may be redirected to the Meta AI app to approve the connection — tap Allow")
                    stepView(12, "Once connected, the camera feed from your glasses will appear in VisionClaude")

                    Divider()

                    sectionHeader("Troubleshooting", icon: "questionmark.circle")
                    bulletPoint("No device found: Make sure glasses are powered on with hinges open")
                    bulletPoint("Stream won't start: Check Developer Mode is ON in Meta AI app")
                    bulletPoint("Glasses need update: Open Meta AI app and follow update prompts")
                    bulletPoint("Connection lost: Close and reopen VisionClaude, or restart glasses")
                    linkButton("DAT Developer Docs", url: "https://wearables.developer.meta.com/docs/develop/")
                    linkButton("Community Forum", url: "https://github.com/facebook/meta-wearables-dat-ios/discussions")

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle("Ray-Ban Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(accentColor)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(accentColor)
                .padding(.top, 7)
            Text(text)
                .font(.body)
        }
        .padding(.leading, 4)
    }

    private func stepView(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.body)
        }
        .padding(.leading, 4)
    }

    private func linkButton(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                Text(title)
            }
            .font(.subheadline)
            .foregroundStyle(accentColor)
        }
        .padding(.leading, 18)
    }
}
