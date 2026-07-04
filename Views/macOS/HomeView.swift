import SwiftUI

/// Home view displaying personalized content sections.
@available(macOS 15.0, *)
struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(TrackLikeStatusManager.self) private var likeStatusManager
    @State private var navigationPath = NavigationPath()
    @State private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        NavigationStack(path: self.$navigationPath) {
            Group {
                if !self.networkMonitor.isConnected {
                    ErrorView(
                        title: "No Connection",
                        message: "Please check your internet connection and try again."
                    ) {
                        Task { await self.viewModel.refresh() }
                    }
                } else {
                    switch self.viewModel.loadingState {
                    case .idle, .loading:
                        HomeLoadingView()
                    case .loaded, .loadingMore, .authRequired:
                        self.contentView
                    case let .error(error):
                        ErrorView(error: error) {
                            Task { await self.viewModel.refresh() }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Home")
            .navigationDestinations(client: self.viewModel.client)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerBar()
        }
        .onAppear {
            if self.viewModel.loadingState == .idle {
                Task {
                    await self.viewModel.load()
                }
            }
        }
        .refreshable {
            await self.viewModel.refresh()
        }
        .background {
            Button("") {
                Task { await self.viewModel.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .opacity(0)
        }
    }

    // MARK: - Views

    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                // Favorites section (hidden when empty)
                if self.favoritesManager.isVisible {
                    FavoritesSection(onNavigate: { destination in
                        if let playlist = destination as? Playlist {
                            self.navigationPath.append(playlist)
                        } else if let artist = destination as? Artist {
                            self.navigationPath.append(artist)
                        } else if let podcastShow = destination as? PodcastShow {
                            self.navigationPath.append(podcastShow)
                        }
                    })
                    .staggeredAppearance(index: 0)
                }

                // API sections - use stable id without array enumeration
                ForEach(self.viewModel.sections) { section in
                    self.sectionView(section)
                        .task {
                            await self.prefetchImagesAsync(for: section)
                        }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private func sectionView(_ section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    // Use stable ID from items, avoid enumeration for non-chart sections
                    if section.isChart {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            HomeSectionItemCard(item: item, rank: index + 1) {
                                self.playItem(item, in: section, at: index)
                            }
                            .contextMenu {
                                self.contextMenuItems(for: item, in: section, at: index)
                            }
                        }
                    } else {
                        ForEach(section.items) { item in
                            HomeSectionItemCard(item: item) {
                                self.playItem(item, in: section, at: 0)
                            }
                            .contextMenu {
                                self.contextMenuItems(for: item, in: section, at: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for item: HomeSectionItem, in _: HomeSection, at _: Int) -> some View {
        switch item {
        case let .track(track):
            Button {
                Task { await self.playbackStore.play(track: track) }
            } label: {
                Label(L("Play"), systemImage: "play.fill")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: track, manager: self.favoritesManager)

            Divider()

            LikeDislikeContextMenu(track: track, likeStatusManager: self.likeStatusManager)

            Divider()

            StartRadioContextMenu.menuItem(for: track, playbackStore: self.playbackStore)

            Divider()

            ShareContextMenu.menuItem(for: track)

            Divider()

            AddToQueueContextMenu(track: track, playbackStore: self.playbackStore)

            if let album = track.album, album.hasNavigableId {
                Divider()

                AlbumPlaybackContextMenu(
                    album: album,
                    client: self.viewModel.client,
                    playbackStore: self.playbackStore
                )
            }

            Divider()

            if let artist = track.artists.first, !artist.id.isEmpty, !artist.id.contains("-") {
                NavigationLink(value: artist) {
                    Label(L("Go to Artist"), systemImage: "person")
                }
            }

            if let album = track.album, album.hasNavigableId {
                let playlist = Playlist(
                    id: album.id,
                    title: album.title,
                    description: nil,
                    thumbnailURL: album.thumbnailURL ?? track.thumbnailURL,
                    trackCount: album.trackCount,
                    author: album.artistsDisplay
                )
                NavigationLink(value: playlist) {
                    Label(L("Go to Album"), systemImage: "square.stack")
                }
            }

        case let .album(album):
            Button {
                self.playItem(item, in: HomeSection(id: "", title: "", items: []), at: 0)
            } label: {
                Label(L("View Album"), systemImage: "square.stack")
            }

            Divider()

            Button {
                TrackActionsHelper.playAlbum(
                    album,
                    client: self.viewModel.client,
                    playbackStore: self.playbackStore
                )
            } label: {
                Label(L("Play Album"), systemImage: "play.fill")
            }

            Button {
                TrackActionsHelper.addAlbumToQueueNext(
                    album,
                    client: self.viewModel.client,
                    playbackStore: self.playbackStore
                )
            } label: {
                Label(L("Add Album Next"), systemImage: "text.insert")
            }

            Button {
                TrackActionsHelper.addAlbumToQueueLast(
                    album,
                    client: self.viewModel.client,
                    playbackStore: self.playbackStore
                )
            } label: {
                Label(L("Add Album to End"), systemImage: "text.append")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: album, manager: self.favoritesManager)

            ShareContextMenu.menuItem(for: album)

        case let .playlist(playlist):
            Button {
                self.navigationPath.append(playlist)
            } label: {
                Label(L("View Playlist"), systemImage: "music.note.list")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: playlist, manager: self.favoritesManager)

            Divider()

            ShareContextMenu.menuItem(for: playlist)

        case let .artist(artist):
            Button {
                self.navigationPath.append(artist)
            } label: {
                Label(L("View Artist"), systemImage: "person")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: artist, manager: self.favoritesManager)

            ShareContextMenu.menuItem(for: artist)
        }
    }

    // MARK: - Image Prefetching

    private static let thumbnailDisplaySize = CGSize(width: 160, height: 160)

    private func prefetchImagesAsync(for section: HomeSection) async {
        // Early exit if task is cancelled
        guard !Task.isCancelled else { return }

        let urls = section.items.prefix(10).compactMap { $0.thumbnailURL?.highQualityThumbnailURL }
        guard !urls.isEmpty else { return }

        await ImageCache.shared.prefetch(
            urls: urls,
            targetSize: Self.thumbnailDisplaySize,
            maxConcurrent: 4
        )
    }

    // MARK: - Actions

    private func playItem(_ item: HomeSectionItem, in _: HomeSection, at _: Int) {
        switch item {
        case let .track(track):
            // Play the track and fetch similar tracks (radio queue) in the background
            Task {
                await self.playbackStore.playWithRadio(track: track)
            }
        case let .playlist(playlist):
            // Navigate to playlist detail
            self.navigationPath.append(playlist)
        case let .album(album):
            // For now, we'll create a playlist-like navigation for albums
            // In a full implementation, we'd have an AlbumDetailView
            let playlist = Playlist(
                id: album.id,
                title: album.title,
                description: nil,
                thumbnailURL: album.thumbnailURL,
                trackCount: album.trackCount,
                author: album.artistsDisplay
            )
            self.navigationPath.append(playlist)
        case let .artist(artist):
            // Navigate to artist detail
            self.navigationPath.append(artist)
        }
    }
}

#Preview {
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    HomeView(viewModel: HomeViewModel(client: client))
        .environment(PlaybackStore())
        .environment(FavoritesManager.shared)
}
