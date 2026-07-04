import AppKit
import SwiftUI

// MARK: - MainWindow

/// Main application window with sidebar navigation and player bar.
@available(macOS 15.0, *)
struct MainWindow: View {
    private struct PresentedWhatsNew: Identifiable {
        let whatsNew: WhatsNew
        let requestedVersion: WhatsNew.Version

        var id: String {
            "\(self.requestedVersion.description)::\(self.whatsNew.version.description)"
        }
    }

    @Environment(AuthService.self) private var authService
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(WebKitManager.self) private var webKitManager
    @Environment(AccountService.self) private var accountService
    @Environment(\.showCommandBar) private var showCommandBar
    @Environment(\.showWhatsNew) private var showWhatsNew
    @Environment(YouTubePlayerService.self) private var youtubePlayerService
    @Environment(PlaybackArbiter.self) private var playbackArbiter

    /// Binding to navigation selection for keyboard shortcut control from parent.
    @Binding var navigationSelection: NavigationItem?

    /// Shared API client used by all views and services.
    let client: any YTMusicClientProtocol

    @State private var showLoginSheet = false
    @State private var showCommandBarSheet = false
    @State private var whatsNewToPresent: PresentedWhatsNew?

    @State private var settings = SettingsManager.shared
    @State private var youtubeNavigationSelection: YouTubeNavigationItem? = .home
    @State private var youtubeViewModel: YouTubeViewModel?

    // MARK: - Cached ViewModels (persist across tab switches)

    @State private var homeViewModel: HomeViewModel?
    @State private var exploreViewModel: ExploreViewModel?
    @State private var searchViewModel: SearchViewModel?
    @State private var chartsViewModel: ChartsViewModel?
    @State private var moodsAndGenresViewModel: MoodsAndGenresViewModel?
    @State private var newReleasesViewModel: NewReleasesViewModel?
    @State private var podcastsViewModel: PodcastsViewModel?
    @State private var likedMusicViewModel: LikedMusicViewModel?
    @State private var libraryViewModel: LibraryViewModel?

    /// Column visibility state for NavigationSplitView - persisted to fix restoration from dock.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(
        navigationSelection: Binding<NavigationItem?>,
        client: any YTMusicClientProtocol,
        youtubeViewModel: YouTubeViewModel? = nil
    ) {
        self._navigationSelection = navigationSelection
        self.client = client
        _homeViewModel = State(initialValue: HomeViewModel(client: client))
        _exploreViewModel = State(initialValue: ExploreViewModel(client: client))
        _searchViewModel = State(initialValue: SearchViewModel(client: client))
        _chartsViewModel = State(initialValue: ChartsViewModel(client: client))
        _moodsAndGenresViewModel = State(initialValue: MoodsAndGenresViewModel(client: client))
        _newReleasesViewModel = State(initialValue: NewReleasesViewModel(client: client))
        _podcastsViewModel = State(initialValue: PodcastsViewModel(client: client))
        _likedMusicViewModel = State(initialValue: LikedMusicViewModel(client: client))
        _libraryViewModel = State(initialValue: LibraryViewModel(client: client))
        _youtubeViewModel = State(initialValue: youtubeViewModel)
    }

    /// Access to the app delegate for persistent WebView.
    private var appDelegate: AppDelegate? {
        NSApplication.shared.delegate as? AppDelegate
    }

    var body: some View {
        @Bindable var player = self.playbackStore

        ZStack(alignment: .bottomTrailing) {
            Group {
                if self.authService.state.isInitializing {
                    // Show loading while checking login status to avoid onboarding flash
                    self.initializingView
                } else if self.authService.state.isLoggedIn {
                    self.mainContent
                } else {
                    OnboardingView()
                }
            }

            // Persistent WebView - always present once a video has been requested
            // Uses a SINGLETON WebView instance that persists for the app lifetime
            // Compact size (120x68) for first-time interaction, then hidden (1x1)
            if let videoId = playbackStore.pendingPlayVideoId {
                ZStack(alignment: .topTrailing) {
                    PersistentPlayerView(videoId: videoId, isExpanded: self.playbackStore.showMiniPlayer)
                        .frame(
                            width: self.playbackStore.showMiniPlayer ? 120 : 1,
                            height: self.playbackStore.showMiniPlayer ? 68 : 1
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .opacity(self.playbackStore.showMiniPlayer ? 0.95 : 0)

                    if self.playbackStore.showMiniPlayer {
                        Button {
                            self.playbackStore.confirmPlaybackStarted()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(radius: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                        .padding(3)
                    }
                }
                .shadow(color: self.playbackStore.showMiniPlayer ? .black.opacity(0.2) : .clear, radius: 6, y: 3)
                .padding(.trailing, self.playbackStore.showMiniPlayer ? 12 : 0)
                .padding(.bottom, self.playbackStore.showMiniPlayer ? 76 : 0)
                .allowsHitTesting(self.playbackStore.showMiniPlayer)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: self.playbackStore.showMiniPlayer)
        .sheet(isPresented: self.$showLoginSheet) {
            LoginSheet()
        }
        .sheet(item: self.$whatsNewToPresent) { presented in
            WhatsNewView(whatsNew: presented.whatsNew) {
                self.dismissWhatsNew(presented)
            }
        }
        .overlay {
            // Command bar overlay - dismisses when clicking outside
            if self.showCommandBarSheet {
                ZStack {
                    // Background tap area to dismiss
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            self.showCommandBarSheet = false
                        }

                    // Command bar centered
                    CommandBarView(client: self.client, isPresented: self.$showCommandBarSheet)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .animation(.easeInOut(duration: 0.15), value: self.showCommandBarSheet)
            }
        }
        .overlay(alignment: .top) {
            // Error toast for account switching failures
            AccountErrorToast()
                .padding(.top, 60)
        }
        .onChange(of: self.showCommandBar.wrappedValue) { _, newValue in
            if newValue {
                self.showCommandBarSheet = true
                self.showCommandBar.wrappedValue = false
            }
        }
        .onChange(of: self.showWhatsNew.wrappedValue) { _, newValue in
            if newValue {
                Task { @MainActor in
                    await self.presentCurrentWhatsNew(
                        respectingPresentedVersions: false,
                        allowsGenericFallback: true
                    )
                }
                self.showWhatsNew.wrappedValue = false
            }
        }
        .onChange(of: self.authService.state) { oldState, newState in
            self.handleAuthStateChange(oldState: oldState, newState: newState)
        }
        .onChange(of: self.authService.needsReauth) { _, needsReauth in
            if needsReauth {
                self.showLoginSheet = true
            }
        }
        .onChange(of: self.playbackStore.isPlaying) { _, isPlaying in
            // Auto-hide the WebView once playback starts
            if isPlaying, self.playbackStore.showMiniPlayer {
                self.playbackStore.confirmPlaybackStarted()
            }
        }
        .onChange(of: self.playbackStore.showVideo) { _, showVideo in
            DiagnosticsLogger.player.debug("showVideo onChange triggered: \(showVideo)")
            if showVideo {
                VideoWindowController.shared.show(
                    playbackStore: self.playbackStore,
                    webKitManager: self.webKitManager
                )
            } else {
                VideoWindowController.shared.close()
            }
        }
        .onChange(of: self.accountService.currentAccount?.id) { _, newAccountId in
            // Refresh all content when user switches accounts
            guard newAccountId != nil else { return }
            DiagnosticsLogger.auth.info("Account switched, refreshing content...")
            // Clear API cache to ensure fresh data for new account
            Task { @MainActor in
                APICache.shared.invalidateAll()
                URLCache.shared.removeAllCachedResponses()
                await self.refreshAllContent()
            }
        }
        .task {
            NowPlayingManager.shared.configure(playbackStore: self.playbackStore)
            
            // Start shortcut monitoring
            ShortcutManager.shared.startMonitoring()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .trailing) {
            // Main navigation content
            LiquidGlassPlayerView {
                HStack(spacing: 0) {
                    Group {
                        switch self.settings.appSource {
                        case .music:
                            Sidebar(selection: self.$navigationSelection)
                        case .video:
                            YouTubeSidebar(selection: self.$youtubeNavigationSelection)
                        case .studio:
                            StudioSidebar()
                        }
                    }
                    .frame(width: 220)
                    .background(Color.clear)
                    
                    Divider().opacity(0.1)
                    
                    Group {
                        if self.settings.appSource == .music {
                            self.detailView(for: self.navigationSelection, client: self.client)
                        } else if self.settings.appSource == .studio {
                            StudioContentView()
                        } else {
                            Group {
                                if let ytVM = self.youtubeViewModel {
                                    YouTubeContentView(
                                        viewModel: ytVM,
                                        selection: self.youtubeNavigationSelection
                                    )
                                } else {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .task {
                                            let accountService = self.accountService
                                            let ytClient = YouTubeClient(webKitManager: WebKitManager.shared)
                                            ytClient.brandIdProvider = { [weak accountService] in
                                                accountService?.currentAccount?.brandId
                                            }
                                            self.youtubeViewModel = YouTubeViewModel(
                                                client: ytClient,
                                                playerService: self.youtubePlayerService
                                            )
                                        }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                }
            }

            // Right sidebar overlay - either lyrics or queue (mutually exclusive)
            self.rightSidebarOverlay(client: self.client)
        }
        .animation(.easeInOut(duration: 0.25), value: self.playbackStore.showLyrics)
        .animation(.easeInOut(duration: 0.25), value: self.playbackStore.showQueue)
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.showCommandBarSheet = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Ask AI (⌘K)")
                .accessibilityIdentifier(AccessibilityID.MainWindow.aiButton)
                .requiresIntelligence()
            }
        }
    }

    /// Right sidebar overlay showing either lyrics or queue as glass panels (mutually exclusive).
    @ViewBuilder
    private func rightSidebarOverlay(client: any YTMusicClientProtocol) -> some View {
        let showRightSidebar = self.playbackStore.showLyrics || self.playbackStore.showQueue

        if showRightSidebar {
            VStack {
                Spacer()

                Group {
                    if self.playbackStore.showLyrics {
                        LyricsView(client: client)
                    } else if self.playbackStore.showQueue {
                        QueueView()
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 76) // Space for PlayerBar
                .transition(.move(edge: .trailing).combined(with: .opacity))

                Spacer()
            }
            .padding(.trailing, 16)
        }
    }

    @ViewBuilder
    private func detailView(for item: NavigationItem?, client _: any YTMusicClientProtocol) -> some View {
        Group {
            if let item {
                self.viewForNavigationItem(item)
            } else {
                Text("Select an item from the sidebar")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Returns the view for a specific navigation item.
    @ViewBuilder
    // swiftlint:disable:next cyclomatic_complexity
    private func viewForNavigationItem(_ item: NavigationItem) -> some View {
        Group {
            switch item {
            case .home:
                if let vm = homeViewModel { HomeView(viewModel: vm) }
            case .explore:
                if let vm = exploreViewModel { ExploreView(viewModel: vm) }
            case .search:
                if let vm = searchViewModel { SearchView(viewModel: vm) }
            case .charts:
                if let vm = chartsViewModel { ChartsView(viewModel: vm) }
            case .moodsAndGenres:
                if let vm = moodsAndGenresViewModel { MoodsAndGenresView(viewModel: vm) }
            case .newReleases:
                if let vm = newReleasesViewModel { NewReleasesView(viewModel: vm) }
            case .podcasts:
                if let vm = podcastsViewModel { PodcastsView(viewModel: vm) }
            case .likedMusic:
                if let vm = likedMusicViewModel { LikedMusicView(viewModel: vm) }
            case .library:
                if let vm = libraryViewModel { LibraryView(viewModel: vm) }
            }
        }
        .environment(self.libraryViewModel)
    }

    /// View shown while checking initial login status.
    private var initializingView: some View {
        VStack(spacing: 16) {
            CassetteIcon(size: 60)
                .foregroundStyle(.tint)
            ProgressView()
                .controlSize(.regular)
                .frame(width: 20, height: 20)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private func handleAuthStateChange(oldState: AuthService.State, newState: AuthService.State) {
        switch newState {
        case .initializing:
            // Still checking login status, do nothing
            break
        case .loggedOut:
            // Onboarding view handles login, no need to auto-show sheet
            self.accountService.clearAccounts()
        case .loggingIn:
            self.showLoginSheet = true
        case .loggedIn:
            self.showLoginSheet = false
            if self.whatsNewToPresent == nil {
                Task { @MainActor in
                    await self.presentCurrentWhatsNew()
                }
            }
            Task {
                await self.accountService.fetchAccounts()
            }
            // If we just completed login (transitioning from loggingIn), refresh content
            // This handles the case where cookies weren't ready during initial load
            if case .loggingIn = oldState {
                Task {
                    // Brief delay to ensure cookies are fully propagated in WebKit
                    try? await Task.sleep(for: .milliseconds(500))

                    // Parallel initial data fetch for ~40% faster app launch
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { await self.homeViewModel?.refresh() }
                        group.addTask { await self.exploreViewModel?.refresh() }
                        group.addTask { await self.libraryViewModel?.load() }
                    }
                }
            }
        }
    }

    @MainActor
    private func dismissWhatsNew(_ whatsNew: PresentedWhatsNew) {
        WhatsNewVersionStore().markPresented(whatsNew.requestedVersion)
        self.whatsNewToPresent = nil
    }

    @MainActor
    private func presentCurrentWhatsNew(
        respectingPresentedVersions: Bool = true,
        allowsGenericFallback: Bool = false
    ) async {
        let currentVersion = WhatsNew.Version.current()
        let whatsNew = await WhatsNewProvider.fetchWhatsNew(
            for: currentVersion,
            respectingPresentedVersions: respectingPresentedVersions
        ) ?? (allowsGenericFallback ? WhatsNewProvider.fallbackCollection.first : nil)

        guard let whatsNew else { return }

        self.whatsNewToPresent = PresentedWhatsNew(
            whatsNew: whatsNew,
            requestedVersion: currentVersion
        )
    }

    /// Refreshes all content when switching accounts.
    ///
    /// This method is called when the user switches between their primary account
    /// and brand accounts, ensuring all views display content for the new account.
    private func refreshAllContent() async {
        // Parallel refresh of all content views
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.homeViewModel?.refresh() }
            group.addTask { await self.exploreViewModel?.refresh() }
            group.addTask { await self.chartsViewModel?.refresh() }
            group.addTask { await self.moodsAndGenresViewModel?.refresh() }
            group.addTask { await self.newReleasesViewModel?.refresh() }
            group.addTask { await self.podcastsViewModel?.refresh() }
            group.addTask { await self.likedMusicViewModel?.refresh() }
            group.addTask { await self.libraryViewModel?.refresh() }
        }
    }
}

// MARK: - NavigationItem


@available(macOS 15.0, *)
#Preview {
    @Previewable @State var navSelection: NavigationItem? = NavigationItem.home
    let authService = AuthService()
    let ytMusicClient = YTMusicClient(authService: authService)
    let accountService = AccountService(ytMusicClient: ytMusicClient, authService: authService)
    MainWindow(navigationSelection: $navSelection, client: ytMusicClient)
        .environment(authService)
        .environment(PlaybackStore())
        .environment(WebKitManager.shared)
        .environment(accountService)
}
