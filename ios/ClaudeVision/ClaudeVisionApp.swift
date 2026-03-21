import SwiftUI
import MWDATCore

@main
struct ClaudeVisionApp: App {
    init() {
        // Initialize Meta Wearables DAT SDK
        do {
            try Wearables.configure()
        } catch {
            print("[ClaudeVision] DAT SDK configuration failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
