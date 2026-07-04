import SwiftUI

/// View displaying all top tracks for an artist.
@available(macOS 15.0, *)
struct TopTracksView: View {
    @State var viewModel: TopTracksViewModel
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(TrackLikeStatusManager.self) private var likeStatusManager

    var body: some View {
        Group {
            switch self.viewModel.loadingState {
            case .idle, .loading:
                if self.viewModel.tracks.isEmpty {
                    LoadingView("Loading tracks...")
                } else {
                    // Show existing tracks while loading more
                    self.tracksListView
                        .overlay(alignment: .top) {
                            if self.viewModel.loadingState == .loading {
                                ProgressView()
                                    .controlSize(.regular)
                                    .frame(width: 20, height: 20)
                                    .padding()
                            }
                        }
                }
            case .loaded, .loadingMore, .authRequired:
                self.tracksListView
            case let .error(error):
                ErrorView(error: error) {
                    Task {
                        await self.viewModel.load()
                    }
                }
            }
        }
        .navigationTitle("Top tracks")
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
        .task {
            if self.viewModel.loadingState == .idle {
                await self.viewModel.load()
            }
        }
    }

    // MARK: - Views

    private var tracksListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(self.viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    self.trackRow(track, index: index)

                    if index < self.viewModel.tracks.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Track Row

    private func trackRow(_ track: Track, index: Int) -> some View {
        Button {
            self.playTrackInQueue(startingAt: index)
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
                }
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 4))

                // Title
                Text(track.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Artist column
                Text(track.artistsDisplay)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)

                // Album column (if available)
                if let album = track.album {
                    Text(album.title)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 180, alignment: .leading)
                } else {
                    Spacer()
                        .frame(width: 180)
                }

                // Duration
                Text(track.durationDisplay)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                self.playTrackInQueue(startingAt: index)
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

            Button {
                TrackActionsHelper.addToLibrary(track, playbackStore: self.playbackStore)
            } label: {
                Label(L("Add to Library"), systemImage: "plus.circle")
            }

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

    // MARK: - Actions

    private func playTrackInQueue(startingAt index: Int) {
        Task {
            await self.playbackStore.playQueue(self.viewModel.tracks, startingAt: index)
        }
    }
}

#Preview {
    let tracks = (1 ... 10).map { i in
        Track(
            id: "track\(i)",
            title: "Track \(i)",
            artists: [Artist(id: "artist1", name: "Test Artist")],
            album: Album(id: "album1", title: "Test Album", artists: nil, thumbnailURL: nil, year: "2023", trackCount: 10),
            duration: TimeInterval(180 + i * 30),
            thumbnailURL: nil,
            videoId: "video\(i)"
        )
    }
    let destination = TopTracksDestination(
        artistId: "artist1",
        artistName: "Test Artist",
        tracks: tracks,
        tracksBrowseId: nil,
        tracksParams: nil
    )
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    TopTracksView(viewModel: TopTracksViewModel(destination: destination, client: client))
        .environment(PlaybackStore())
        .environment(FavoritesManager.shared)
}
