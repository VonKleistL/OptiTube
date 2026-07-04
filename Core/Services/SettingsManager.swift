import Observation
import AppKit

/// Represents a custom keyboard shortcut.
struct UserShortcut: Codable, Hashable, Sendable {
    let keyCode: UInt16
    let modifierFlags: NSEvent.ModifierFlags.RawValue
    let actionIdentifier: String

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }
}

/// Manages user preferences persisted via UserDefaults.
@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    // MARK: - Settings Keys

    private enum Keys {
        static let showNowPlayingNotifications = "settings.showNowPlayingNotifications"
        static let defaultLaunchPage = "settings.defaultLaunchPage"
        static let hapticFeedbackEnabled = "settings.hapticFeedbackEnabled"
        static let rememberPlaybackSettings = "settings.rememberPlaybackSettings"
        static let autoPilotEnabled = "settings.autoPilotEnabled"
        static let lastFmSessionKey = "settings.lastFmSessionKey"
        static let scrobblingEnabled = "settings.scrobblingEnabled"
        static let customShortcuts = "settings.customShortcuts"
        static let discordRpcEnabled = "settings.discordRpcEnabled"
        static let currentTheme = "settings.currentTheme"
        static let enabledServices = "settings.enabledServices"
        static let scrobblePercentThreshold = "settings.scrobblePercentThreshold"
        static let scrobbleMinSeconds = "settings.scrobbleMinSeconds"
        static let mediaControlStyle = "settings.mediaControlStyle"
        static let syncedLyricsEnabled = "settings.syncedLyricsEnabled"
        static let popOutVideoOnNavigateAway = "settings.popOutVideoOnNavigateAway"
        static let romanizationEnabled = "settings.romanizationEnabled"
        static let ambientBackdropEnabled = "settings.ambientBackdropEnabled"
        static let appSource = "settings.appSource"
        static let useLegacyMacOS15UI = "settings.debug.useLegacyMacOS15UI"
    }

    // MARK: - App Themes

    /// Available visual themes for the application.
    enum AppTheme: String, CaseIterable, Identifiable {
        case optiTube = "OptiTube"
        case nightshade = "Nightshade (Galaxy)"
        case darkness = "Darkness"
        case optiGlass = "OptiGlass"

        var id: String { rawValue }
    }

    // MARK: - Launch Page Options

    /// Available pages to launch the app with.
    enum LaunchPage: String, CaseIterable, Identifiable {
        case home
        case explore
        case charts
        case moodsAndGenres
        case newReleases
        case likedMusic
        case playlists
        case lastUsed

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .home: L("Home")
            case .explore: L("Explore")
            case .charts: L("Charts")
            case .moodsAndGenres: L("Moods & Genres")
            case .newReleases: L("New Releases")
            case .likedMusic: L("Liked Music")
            case .playlists: L("Playlists")
            case .lastUsed: L("Last Used")
            }
        }

        /// Converts LaunchPage to NavigationItem for navigation.
        var navigationItem: NavigationItem {
            switch self {
            case .home: .home
            case .explore: .explore
            case .charts: .charts
            case .moodsAndGenres: .moodsAndGenres
            case .newReleases: .newReleases
            case .likedMusic: .likedMusic
            case .playlists: .library
            case .lastUsed: .home // Fallback
            }
        }
    }

    // MARK: - Media Control Style

    /// Controls which command style to use in Control Center media controls.
    enum MediaControlStyle: String, CaseIterable, Identifiable {
        case skipForwardBackward
        case nextPreviousTrack

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .skipForwardBackward: L("Skip Forward/Backward")
            case .nextPreviousTrack: L("Next/Previous Track")
            }
        }
    }

    // MARK: - Settings Properties

    /// Whether to show system notifications when the track changes.
    var showNowPlayingNotifications: Bool {
        didSet {
            UserDefaults.standard.set(self.showNowPlayingNotifications, forKey: Keys.showNowPlayingNotifications)
        }
    }

    /// The default page to show when the app launches.
    var defaultLaunchPage: LaunchPage {
        didSet {
            UserDefaults.standard.set(self.defaultLaunchPage.rawValue, forKey: Keys.defaultLaunchPage)
        }
    }

    /// Whether haptic feedback is enabled.
    var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.hapticFeedbackEnabled, forKey: Keys.hapticFeedbackEnabled)
        }
    }

    /// Whether to remember shuffle/repeat settings across app restarts.
    var rememberPlaybackSettings: Bool {
        didSet {
            UserDefaults.standard.set(self.rememberPlaybackSettings, forKey: Keys.rememberPlaybackSettings)
            if !self.rememberPlaybackSettings {
                UserDefaults.standard.removeObject(forKey: "playerShuffleEnabled")
                UserDefaults.standard.removeObject(forKey: "playerRepeatMode")
            }
        }
    }

    /// Whether the Intelligent Queue (Auto-Pilot) is enabled.
    var autoPilotEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.autoPilotEnabled, forKey: Keys.autoPilotEnabled)
        }
    }

    /// Last.fm session key for scrobbling.
    var lastFmSessionKey: String? {
        didSet {
            UserDefaults.standard.set(self.lastFmSessionKey, forKey: Keys.lastFmSessionKey)
        }
    }

    /// Whether scrobbling to Last.fm is enabled.
    var scrobblingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.scrobblingEnabled, forKey: Keys.scrobblingEnabled)
        }
    }

    /// Custom keyboard shortcuts defined by the user.
    var customShortcuts: [UserShortcut] {
        didSet {
            if let data = try? JSONEncoder().encode(self.customShortcuts) {
                UserDefaults.standard.set(data, forKey: Keys.customShortcuts)
            }
        }
    }

    /// Whether Discord Rich Presence is enabled.
    var discordRpcEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.discordRpcEnabled, forKey: Keys.discordRpcEnabled)
        }
    }

    /// The current visual theme of the app.
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(self.currentTheme.rawValue, forKey: Keys.currentTheme)
        }
    }

    /// Preferred media control command style for Now Playing.
    var mediaControlStyle: MediaControlStyle {
        didSet {
            UserDefaults.standard.set(self.mediaControlStyle.rawValue, forKey: Keys.mediaControlStyle)
        }
    }

    /// Whether synced lyrics fetch is enabled.
    var syncedLyricsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.syncedLyricsEnabled, forKey: Keys.syncedLyricsEnabled)
        }
    }

    /// Whether romanization is enabled for non-Latin lyrics.
    var romanizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.romanizationEnabled, forKey: Keys.romanizationEnabled)
        }
    }

    /// Whether to pop out video window on navigate away.
    var popOutVideoOnNavigateAway: Bool {
        didSet {
            UserDefaults.standard.set(self.popOutVideoOnNavigateAway, forKey: Keys.popOutVideoOnNavigateAway)
        }
    }

    /// Whether the ambient backdrop effect is enabled.
    var ambientBackdropEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.ambientBackdropEnabled, forKey: Keys.ambientBackdropEnabled)
        }
    }

    /// The active content source for the app-wide experience (Music or YouTube).
    var appSource: AppSource {
        didSet {
            UserDefaults.standard.set(self.appSource.rawValue, forKey: Keys.appSource)
        }
    }

    /// Whether to force legacy macOS 15 UI fallback.
    var useLegacyMacOS15UI: Bool {
        didSet {
            UserDefaults.standard.set(self.useLegacyMacOS15UI, forKey: Keys.useLegacyMacOS15UI)
        }
    }

    /// The last page the user was on.
    var lastUsedPage: LaunchPage = .home

    // MARK: - Initialization

    private init() {
        self.showNowPlayingNotifications = UserDefaults.standard.object(forKey: Keys.showNowPlayingNotifications) as? Bool ?? true
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: Keys.hapticFeedbackEnabled) as? Bool ?? true
        self.rememberPlaybackSettings = UserDefaults.standard.object(forKey: Keys.rememberPlaybackSettings) as? Bool ?? false
        self.autoPilotEnabled = UserDefaults.standard.object(forKey: Keys.autoPilotEnabled) as? Bool ?? true
        self.lastFmSessionKey = UserDefaults.standard.string(forKey: Keys.lastFmSessionKey)
        self.scrobblingEnabled = UserDefaults.standard.object(forKey: Keys.scrobblingEnabled) as? Bool ?? false
        self.discordRpcEnabled = UserDefaults.standard.object(forKey: Keys.discordRpcEnabled) as? Bool ?? true
        self.syncedLyricsEnabled = UserDefaults.standard.object(forKey: Keys.syncedLyricsEnabled) as? Bool ?? true
        self.romanizationEnabled = UserDefaults.standard.object(forKey: Keys.romanizationEnabled) as? Bool ?? true
        self.popOutVideoOnNavigateAway = UserDefaults.standard.object(forKey: Keys.popOutVideoOnNavigateAway) as? Bool ?? true
        self.ambientBackdropEnabled = UserDefaults.standard.object(forKey: Keys.ambientBackdropEnabled) as? Bool ?? true
        self.useLegacyMacOS15UI = UserDefaults.standard.object(forKey: Keys.useLegacyMacOS15UI) as? Bool ?? false

        if let sourceRaw = UserDefaults.standard.string(forKey: Keys.appSource),
           let source = AppSource(rawValue: sourceRaw) {
            self.appSource = source
        } else {
            self.appSource = .music
        }

        if let themeRaw = UserDefaults.standard.string(forKey: Keys.currentTheme),
           let theme = AppTheme(rawValue: themeRaw) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .optiTube
        }

        if let styleRaw = UserDefaults.standard.string(forKey: Keys.mediaControlStyle),
           let style = MediaControlStyle(rawValue: styleRaw) {
            self.mediaControlStyle = style
        } else {
            self.mediaControlStyle = .nextPreviousTrack
        }

        if let data = UserDefaults.standard.data(forKey: Keys.customShortcuts),
           let decoded = try? JSONDecoder().decode([UserShortcut].self, from: data) {
            self.customShortcuts = decoded
        } else {
            self.customShortcuts = [
                UserShortcut(keyCode: 49, modifierFlags: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue, actionIdentifier: "playback.playPause"),
                UserShortcut(keyCode: 124, modifierFlags: NSEvent.ModifierFlags.command.rawValue, actionIdentifier: "playback.next"),
                UserShortcut(keyCode: 123, modifierFlags: NSEvent.ModifierFlags.command.rawValue, actionIdentifier: "playback.previous")
            ]
        }

        if let rawValue = UserDefaults.standard.string(forKey: Keys.defaultLaunchPage),
           let page = LaunchPage(rawValue: rawValue) {
            self.defaultLaunchPage = page
        } else {
            self.defaultLaunchPage = .home
        }
    }

    // MARK: - Computed Properties

    var launchPage: LaunchPage {
        switch self.defaultLaunchPage {
        case .lastUsed:
            self.lastUsedPage
        default:
            self.defaultLaunchPage
        }
    }

    var launchNavigationItem: NavigationItem {
        self.launchPage.navigationItem
    }

    // MARK: - Scrobbling Settings Extension

    private var enabledServices: [String: Bool] {
        get { UserDefaults.standard.dictionary(forKey: Keys.enabledServices) as? [String: Bool] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enabledServices) }
    }

    func isServiceEnabled(_ serviceName: String) -> Bool {
        enabledServices[serviceName] ?? false
    }

    func setServiceEnabled(_ serviceName: String, _ enabled: Bool) {
        var services = enabledServices
        services[serviceName] = enabled
        enabledServices = services
    }

    var scrobblePercentThreshold: Double {
        get { UserDefaults.standard.object(forKey: Keys.scrobblePercentThreshold) as? Double ?? 0.5 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.scrobblePercentThreshold) }
    }

    var scrobbleMinSeconds: Double {
        get { UserDefaults.standard.object(forKey: Keys.scrobbleMinSeconds) as? Double ?? 240.0 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.scrobbleMinSeconds) }
    }
}
