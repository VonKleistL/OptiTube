import AppIntents
import Foundation

/// Intent to toggle play/pause in OptiTube.
@available(macOS 13.0, *)
struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource { "Play/Pause" }
    static var description: IntentDescription { IntentDescription("Toggles music playback in OptiTube.") }

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackStore.shared?.playPause()
        return .result()
    }
}

/// Intent to skip to the next track.
@available(macOS 13.0, *)
struct SkipNextIntent: AppIntent {
    static var title: LocalizedStringResource { "Skip Next" }
    static var description: IntentDescription { IntentDescription("Plays the next track in the queue.") }

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackStore.shared?.next()
        return .result()
    }
}

/// Intent to skip to the previous track.
@available(macOS 13.0, *)
struct SkipPreviousIntent: AppIntent {
    static var title: LocalizedStringResource { "Skip Previous" }
    static var description: IntentDescription { IntentDescription("Plays the previous track or restarts the current one.") }

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackStore.shared?.previous()
        return .result()
    }
}

/// Provides system-wide shortcuts for OptiTube commands.
@available(macOS 13.0, *)
struct OptiTubeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayPauseIntent(),
            phrases: [
                "Play music in \(.applicationName)",
                "Pause music in \(.applicationName)",
                "Toggle playback in \(.applicationName)"
            ],
            shortTitle: "Play/Pause",
            systemImageName: "playpause.fill"
        )
        
        AppShortcut(
            intent: SkipNextIntent(),
            phrases: [
                "Skip this track in \(.applicationName)",
                "Next song in \(.applicationName)"
            ],
            shortTitle: "Skip Next",
            systemImageName: "forward.fill"
        )
    }
}
