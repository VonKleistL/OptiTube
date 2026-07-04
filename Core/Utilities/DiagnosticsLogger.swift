import Foundation
import os

/// Centralized logging for the OptiTube app.
enum DiagnosticsLogger {
    /// Logger for authentication-related events.
    static let auth = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Auth")

    /// Logger for API-related events.
    static let api = Logger(subsystem: "com.VonKleistL.OptiTube", category: "API")

    /// Logger for WebKit-related events.
    static let webKit = Logger(subsystem: "com.VonKleistL.OptiTube", category: "WebKit")

    /// Logger for player-related events.
    static let player = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Player")

    /// Logger for UI-related events.
    static let ui = Logger(subsystem: "com.VonKleistL.OptiTube", category: "UI")

    /// Logger for notification-related events.
    static let notification = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Notification")

    /// Logger for AI/Foundation Models-related events.
    static let ai = Logger(subsystem: "com.VonKleistL.OptiTube", category: "AI")

    /// Logger for haptic feedback-related events.
    static let haptic = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Haptic")

    /// Logger for network connectivity-related events.
    static let network = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Network")

    /// Logger for updater/general app events.
    static let updater = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Updater")

    /// Logger for app lifecycle and URL handling events.
    static let app = Logger(subsystem: "com.VonKleistL.OptiTube", category: "App")

    /// Logger for AppleScript scripting events.
    static let scripting = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Scripting")

    /// Logger for AirPlay-related events.
    static let airplay = Logger(subsystem: "com.VonKleistL.OptiTube", category: "AirPlay")

    /// Logger for scrobbling-related events (Last.fm, etc.).
    static let scrobbling = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Scrobbling")

    /// Logger for equalizer-related events.
    static let equalizer = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Equalizer")

    /// Logger for extensions-related events.
    static let extensions = Logger(subsystem: "com.VonKleistL.OptiTube", category: "Extensions")
}

