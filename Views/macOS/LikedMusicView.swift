import SwiftUI

/// View displaying the user's liked tracks.
@available(macOS 15.0, *)
struct LikedMusicView: View {
    @State var viewModel: LikedMusicViewModel
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(TrackLikeStatusManager.self) private var likeStatusManager
    @State private var networkMonitor = NetworkMonitor.shared

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: self.$navigationPath) {
            Group {
                if !self.networkMonitor.isConnected {
                    ErrorView(
                        title: L("No Connection"),
                        message: L("Please check your internet connection and try again.")
                    ) {
                        Task { await self.viewModel.refresh() }
                    }
                } else {
                    switch self.viewModel.loadingState {
                    case .idle, .loading:
                        LoadingView(L("Loading liked tracks..."))
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
            .navigationTitle(L("Liked Music"))
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(
                    artist: artist,
                    viewModel: ArtistDetailViewModel(
                        artist: artist,
                        client: self.viewModel.client
                    )
                )
            }
            .navigationDestination(for: TopTracksDestination.self) { destination in
                TopTracksView(
                    viewModel: TopTracksViewModel(
                        destination: destination,
                        client: self.viewModel.client
                    ))
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(
                    playlist: playlist,
                    viewModel: PlaylistDetailViewModel(
                        playlist: playlist,
                        client: self.viewModel.client
                    )
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerBar()
        }
        .task {
            if self.viewModel.loadingState == .idle {
                await self.viewModel.load()
            }
        }
        .refreshable {
            await self.viewModel.refresh()
        }
    }

    // MARK: - Views

    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header with play all button
                self.headerView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Tracks list
                if self.viewModel.tracks.isEmpty {
                    self.emptyStateView
                } else {
                    ForEach(Array(self.viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                        self.trackRow(track, index: index)
                            .onAppear {
                                // Load more when reaching the last few items
                                if index >= self.viewModel.tracks.count - 3, self.viewModel.hasMore {
                                    Task { await self.viewModel.loadMore() }
                                }
                            }
                        if index < self.viewModel.tracks.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }

                    // Loading indicator for pagination
                    if self.viewModel.loadingState == .loadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            // Liked music icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("Liked Music"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(LF("%lld tracks", Int64(self.viewModel.tracks.count)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Play all button
            if !self.viewModel.tracks.isEmpty {
                Button {
                    Task {
                        await self.playbackStore.playQueue(self.viewModel.tracks, startingAt: 0)
                    }
                } label: {
                    Label(L("Play All"), systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Shuffle button
                Button {
                    Task {
                        let shuffled = self.viewModel.tracks.shuffled()
                        await self.playbackStore.playQueue(shuffled, startingAt: 0)
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(L("No liked tracks yet"))
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(L("Tracks you like will appear here"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func trackRow(_ track: Track, index: Int) -> some View {
        Button {
            Task {
                await self.playbackStore.playQueue(self.viewModel.tracks, startingAt: index)
            }
        } label: {
            HStack(spacing: 12) {
                // Thumbnail
                CachedAsyncImage(url: track.thumbnailURL?.highQualityThumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 6))

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14))
                        .lineLimit(1)

                    Text(track.artistsDisplay)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Duration
                Text(track.durationDisplay)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                // Play indicator
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task { await self.playbackStore.play(track: track) }
            } label: {
                Label(L("Play"), systemImage: "play.fill")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: track, manager: self.favoritesManager)

            Divider()

            Button {
                TrackActionsHelper.unlikeTrack(track, likeStatusManager: self.likeStatusManager)
            } label: {
                Label(L("Unlike"), systemImage: "hand.thumbsup.fill")
            }

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

            // Go to Artist - show first artist with valid ID
            if let artist = track.artists.first(where: { $0.hasNavigableId }) {
                NavigationLink(value: artist) {
                    Label(L("Go to Artist"), systemImage: "person")
                }
            }

            // Go to Album - show if album has valid browse ID
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
        }
    }
}

#Preview {
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    LikedMusicView(viewModel: LikedMusicViewModel(client: client))
        .environment(PlaybackStore())
        .environment(FavoritesManager.shared)
}
