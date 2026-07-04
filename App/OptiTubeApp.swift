import AppKit
import SwiftUI

// MARK: - SearchFocusTriggerKey

/// Environment key for triggering search focus from keyboard shortcut.
struct SearchFocusTriggerKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var searchFocusTrigger: Binding<Bool> {
        get { self[SearchFocusTriggerKey.self] }
        set { self[SearchFocusTriggerKey.self] = newValue }
    }
}

// MARK: - NavigationSelectionKey

/// Environment key for navigation selection.
struct NavigationSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationItem?> = .constant(nil)
}

extension EnvironmentValues {
    var navigationSelection: Binding<NavigationItem?> {
        get { self[NavigationSelectionKey.self] }
        set { self[NavigationSelectionKey.self] = newValue }
    }
}

// MARK: - CommandBarVisibilityKey

/// Environment key for command bar visibility.
struct CommandBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showCommandBar: Binding<Bool> {
        get { self[CommandBarVisibilityKey.self] }
        set { self[CommandBarVisibilityKey.self] = newValue }
    }
}

// MARK: - WhatsNewVisibilityKey

/// Environment key for manually presenting What's New.
struct WhatsNewVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showWhatsNew: Binding<Bool> {
        get { self[WhatsNewVisibilityKey.self] }
        set { self[WhatsNewVisibilityKey.self] = newValue }
    }
}

// MARK: - UsesLegacyMacOS15UIKey

/// Environment key for legacy macOS 15 UI fallback.
struct UsesLegacyMacOS15UIKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var usesLegacyMacOS15UI: Bool {
        get { self[UsesLegacyMacOS15UIKey.self] }
        set { self[UsesLegacyMacOS15UIKey.self] = newValue }
    }
}

// MARK: - OptiTubeApp

/// Main entry point for the OptiTube macOS application.
@available(macOS 15.0, *)
@main
struct OptiTubeApp: App {
    /// App delegate for lifecycle management (background playback).
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var settings = SettingsManager.shared
    @State private var authService = AuthService()
    @State private var webKitManager = WebKitManager.shared
    @State private var playbackStore = PlaybackStore()
    @State private var youtubePlayerService = YouTubePlayerService()
    @State private var playbackArbiter: PlaybackArbiter
    @State private var sharedClient: any YTMusicClientProtocol
    @State private var notificationService: NotificationService?
    @State private var favoritesManager = FavoritesManager.shared
    @State private var likeStatusManager = TrackLikeStatusManager.shared
    @State private var accountService: AccountService?
    @State private var scrobblingCoordinator: ScrobblingCoordinator

    /// Triggers search field focus when set to true.
    @State private var searchFocusTrigger = false

    /// Current navigation selection for keyboard navigation.
    @State private var navigationSelection: NavigationItem? = SettingsManager.shared.launchNavigationItem

    /// Whether the command bar is visible.
    @State private var showCommandBar = false

    /// Whether the What's New sheet should be shown.
    @State private var showWhatsNew = false

    init() {
        let auth = AuthService()
        let webkit = WebKitManager.shared
        let player = PlaybackStore()

        // Use mock client in UI test mode, real client otherwise
        let realClient = YTMusicClient(authService: auth, webKitManager: webkit)
        let client: YTMusicClientProtocol = if UITestConfig.isUITestMode {
            MockUITestYTMusicClient()
        } else {
            realClient
        }

        // Wire up dependencies
        player.setYTMusicClient(client)
        TrackLikeStatusManager.shared.setClient(client)

        // Set shared instance for AppleScript access
        PlaybackStore.shared = player

        // Create account service
        let account = AccountService(ytMusicClient: client, authService: auth, webKitManager: webkit)

        // Wire up brand account provider so API requests use the correct account
        realClient.brandIdProvider = { [weak account] in
            account?.currentBrandId
        }

        _authService = State(initialValue: auth)
        _webKitManager = State(initialValue: webkit)
        _playbackStore = State(initialValue: player)
        _sharedClient = State(initialValue: client)
        _notificationService = State(initialValue: NotificationService(playbackStore: player))
        _accountService = State(initialValue: account)

        // Create scrobbling coordinator
        let lastFMService = LastFMService(credentialStore: KeychainCredentialStore())
        let scrobblingCoordinator = ScrobblingCoordinator(
            playbackStore: player,
            services: [lastFMService]
        )
        scrobblingCoordinator.restoreAuthState()
        scrobblingCoordinator.startMonitoring()
        _scrobblingCoordinator = State(initialValue: scrobblingCoordinator)

        // Create YouTube video mode players
        let youtubePlayer = YouTubePlayerService()
        let arbiter = PlaybackArbiter(playerService: player, youtubePlayerService: youtubePlayer)
        player.playbackWillStart = { [weak arbiter] in
            arbiter?.musicDidStartPlaying()
        }
        _youtubePlayerService = State(initialValue: youtubePlayer)
        _playbackArbiter = State(initialValue: arbiter)

        // Wire up PlaybackStore to AppDelegate so lifecycle callbacks
        // (startup restore / termination persistence) can access it.
        self.appDelegate.playbackStore = player

        if UITestConfig.isUITestMode {
            DiagnosticsLogger.ui.info("App launched in UI Test mode")
        }
    }

    var body: some Scene {
        Window("OptiTube", id: "main") {
            // Skip UI during unit tests to prevent window spam
            if UITestConfig.isRunningUnitTests, !UITestConfig.isUITestMode {
                Color.clear
                    .frame(width: 1, height: 1)
            } else {
                 MainWindow(navigationSelection: self.$navigationSelection, client: self.sharedClient)
                    .environment(self.authService)
                    .environment(self.webKitManager)
                    .environment(self.playbackStore)
                    .environment(self.youtubePlayerService)
                    .environment(self.playbackArbiter)
                    .environment(self.favoritesManager)
                    .environment(self.likeStatusManager)
                    .environment(self.accountService)
                    .environment(self.scrobblingCoordinator)
                    .environment(\.searchFocusTrigger, self.$searchFocusTrigger)
                    .environment(\.navigationSelection, self.$navigationSelection)
                    .environment(\.showCommandBar, self.$showCommandBar)
                    .environment(\.showWhatsNew, self.$showWhatsNew)
                    .environment(\.usesLegacyMacOS15UI, self.settings.useLegacyMacOS15UI)
                    .onAppear {
                        // Wire up PlaybackStore to AppDelegate for dock menu and AppleScript actions
                        // This runs synchronously so AppleScript commands can access playbackStore immediately
                        self.appDelegate.playbackStore = self.playbackStore

                        // Setup Menu Bar presence
                        MenuBarController.shared.setup(
                            playbackStore: self.playbackStore,
                            youtubePlayerService: self.youtubePlayerService
                        )
                    }
                    .task {
                        // Check if user is already logged in from previous session
                        await self.authService.checkLoginStatus()

                        // Fetch accounts after login check (for account switcher)
                        await self.accountService?.fetchAccounts()

                        // Warm up Foundation Models in background
                        await FoundationModelsService.shared.warmup()
                    }
                    .onOpenURL { url in
                        self.handleIncomingURL(url)
                    }
            }
        }

        Settings {
            SettingsView()
                .environment(self.authService)
                .environment(self.scrobblingCoordinator)
        }
        .commands {
            // Help menu - What's New
            CommandGroup(after: .help) {
                Button(L("What's New in OptiTube")) {
                    self.showWhatsNew = true
                }
            }

            // Playback commands
            CommandMenu("Playback") {
                // Play/Pause - Space
                Button(self.playbackStore.isPlaying ? "Pause" : "Play") {
                    Task {
                        await self.playbackStore.playPause()
                    }
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(self.playbackStore.currentTrack == nil && self.playbackStore.pendingPlayVideoId == nil)

                Divider()

                // Next Track - ⌘→
                Button("Next") {
                    Task {
                        await self.playbackStore.next()
                    }
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                // Previous Track - ⌘←
                Button("Previous") {
                    Task {
                        await self.playbackStore.previous()
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                // Volume Up - ⌘↑
                Button("Volume Up") {
                    Task {
                        await self.playbackStore.setVolume(min(1.0, self.playbackStore.volume + 0.1))
                    }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                // Volume Down - ⌘↓
                Button("Volume Down") {
                    Task {
                        await self.playbackStore.setVolume(max(0.0, self.playbackStore.volume - 0.1))
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                // Mute - ⌥M
                Button(self.playbackStore.isMuted ? "Unmute" : "Mute") {
                    Task {
                        await self.playbackStore.toggleMute()
                    }
                }
                .keyboardShortcut("m", modifiers: [.option])

                Divider()

                // Shuffle - ⌘S
                Button(self.playbackStore.shuffleEnabled ? "Shuffle Off" : "Shuffle On") {
                    self.playbackStore.toggleShuffle()
                }
                .keyboardShortcut("s", modifiers: .command)

                // Repeat - ⌘R
                Button(self.repeatModeLabel) {
                    self.playbackStore.cycleRepeatMode()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                // Lyrics - ⌘L
                Button(self.playbackStore.showLyrics ? "Hide Lyrics" : "Show Lyrics") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.playbackStore.showLyrics.toggle()
                    }
                }
                .keyboardShortcut("l", modifiers: .command)
            }

            // Navigation commands - replace default sidebar toggle
            CommandGroup(replacing: .sidebar) {
                // Home - ⌘1
                Button("Home") {
                    self.navigationSelection = .home
                }
                .keyboardShortcut("1", modifiers: .command)

                // Explore - ⌘2
                Button("Explore") {
                    self.navigationSelection = .explore
                }
                .keyboardShortcut("2", modifiers: .command)

                // Library - ⌘3
                Button("Library") {
                    self.navigationSelection = .library
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                // Search - ⌘F
                Button("Search") {
                    self.navigationSelection = .search
                    // Trigger focus after a brief delay to allow view to appear
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        self.searchFocusTrigger = true
                    }
                }
                .keyboardShortcut("f", modifiers: .command)

                // Command Bar - ⌘K
                Button("Command Bar") {
                    self.showCommandBar = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            // Window menu - show main window and standard actions
            CommandGroup(after: .windowArrangement) {
                Button("Minimize") {
                    NSApplication.shared.keyWindow?.miniaturize(nil)
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("OptiTube") {
                    self.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }

    /// Shows the main window.
    private func showMainWindow() {
        // Find and show the main window
        for window in NSApplication.shared.windows where window.frameAutosaveName == "OptiTubeMainWindow" {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        // Fallback: find any main-capable window that's not the video window
        for window in NSApplication.shared.windows where window.canBecomeMain {
            if window.identifier?.rawValue == AccessibilityID.VideoWindow.container {
                continue
            }
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
    }

    /// Label for repeat mode menu item.
    private var repeatModeLabel: String {
        switch self.playbackStore.repeatMode {
        case .off:
            "Repeat All"
        case .all:
            "Repeat One"
        case .one:
            "Repeat Off"
        }
    }

    // MARK: - URL Handling

    /// Handles an incoming URL (from custom scheme).
    private func handleIncomingURL(_ url: URL) {
        DiagnosticsLogger.app.info("Received URL: \(url.absoluteString)")

        guard let content = URLHandler.parse(url) else {
            DiagnosticsLogger.app.warning("Unrecognized URL format: \(url.absoluteString)")
            return
        }

        // If not logged in, ignore for now
        guard self.authService.state.isLoggedIn else {
            DiagnosticsLogger.app.info("Not logged in, ignoring URL")
            return
        }

        self.handleParsedContent(content)
    }

    /// Handles parsed URL content.
    private func handleParsedContent(_ content: URLHandler.ParsedContent) {
        switch content {
        case let .track(videoId):
            DiagnosticsLogger.app.info("Playing track from URL: \(videoId)")
            let track = Track(
                id: videoId,
                title: "Loading...",
                artists: [],
                videoId: videoId
            )
            Task {
                await self.playbackStore.play(track: track)
            }

        case .playlist, .album, .artist:
            // Only track playback is supported via URL scheme
            DiagnosticsLogger.app.info("URL scheme only supports track playback")
        }
    }
}

// MARK: - SettingsView

/// Main settings view with tabbed navigation.
@available(macOS 15.0, *)
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            IntelligenceSettingsView()
                .tabItem {
                    Label("Intelligence", systemImage: "sparkles")
                }

            ScrobblingSettingsView()
                .tabItem {
                    Label("Scrobbling", systemImage: "radio")
                }

            ExtensionsSettingsView()
                .tabItem {
                    Label("Extensions", systemImage: "puzzlepiece.extension")
                }
        }
        .frame(width: 520, height: 520)
    }
}
