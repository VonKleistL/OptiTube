import SwiftUI

/// Detail view for an artist showing their tracks and albums.
@available(macOS 15.0, *)
struct ArtistDetailView: View {
    let artist: Artist
    @State var viewModel: ArtistDetailViewModel
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(TrackLikeStatusManager.self) private var likeStatusManager

    var body: some View {
        Group {
            switch self.viewModel.loadingState {
            case .idle, .loading:
                LoadingView(L("Loading artist..."))
            case .loaded, .loadingMore, .authRequired:
                if let detail = viewModel.artistDetail {
                    self.contentView(detail)
                } else {
                    ErrorView(title: L("Unable to load artist"), message: L("Artist not found")) {
                        Task { await self.viewModel.load() }
                    }
                }
            case let .error(error):
                ErrorView(error: error) {
                    Task { await self.viewModel.load() }
                }
            }
        }
        .navigationTitle(self.artist.name)
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
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

    private func contentView(_ detail: ArtistDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                self.headerView(detail)

                Divider()

                // Tracks section
                if !detail.tracks.isEmpty {
                    self.tracksSection()
                }

                // Albums section
                if !detail.albums.isEmpty {
                    self.albumsSection(detail.albums)
                }
            }
            .padding(24)
        }
    }

    private func headerView(_ detail: ArtistDetail) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Thumbnail
            CachedAsyncImage(url: detail.thumbnailURL?.highQualityThumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 180, height: 180)
            .clipShape(.circle)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Artist"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(detail.name)
                    .font(.title)
                    .fontWeight(.bold)

                // Subscriber count
                if let subscriberCount = detail.subscriberCount {
                    Text(subscriberCount)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let description = detail.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                HStack(spacing: 12) {
                    // Shuffle button - shuffles all artist's tracks (fetches if needed)
                    Button {
                        Task {
                            await self.shuffleAllTracks()
                        }
                    } label: {
                        Label(L("Shuffle"), systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(detail.tracks.isEmpty && !detail.hasMoreTracks)

                    // Mix button - plays personalized radio with mix of artists
                    // Only shown if mix data is available from the API
                    // Passing nil for startVideoId lets the API pick a random starting point on the server
                    // in addition to client-side shuffling applied when the mix tracks are played
                    if let mixPlaylistId = detail.mixPlaylistId {
                        Button {
                            self.playMix(playlistId: mixPlaylistId, startVideoId: nil)
                        } label: {
                            Label(L("Mix"), systemImage: "play.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    // Subscribe button
                    if detail.channelId != nil {
                        self.subscribeButton(detail)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Returns the text for the subscribe button.
    private func subscribeButtonText(_ detail: ArtistDetail) -> String {
        if detail.isSubscribed {
            return L("Subscribed")
        }
        // Format subscriber count (e.g., "Subscribe 34.6M")
        if let count = detail.subscriberCount {
            // Extract just the number part if it contains "subscribers"
            let numberPart = count
                .replacingOccurrences(of: " subscribers", with: "")
                .replacingOccurrences(of: " subscriber", with: "")
            return LF("Subscribe %@", numberPart)
        }
        return L("Subscribe")
    }

    @ViewBuilder
    private func subscribeButton(_ detail: ArtistDetail) -> some View {
        if detail.isSubscribed {
            Button {
                HapticService.toggle()
                Task {
                    await self.viewModel.toggleSubscription()
                }
            } label: {
                if self.viewModel.isSubscribing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Text(self.subscribeButtonText(detail))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(self.viewModel.isSubscribing)
        } else {
            Button {
                HapticService.toggle()
                Task {
                    await self.viewModel.toggleSubscription()
                }
            } label: {
                if self.viewModel.isSubscribing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Text(self.subscribeButtonText(detail))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(self.viewModel.isSubscribing)
        }
    }

    private func tracksSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Top tracks"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // See all button - navigates to full top tracks view
                if self.viewModel.hasMoreTracks, let detail = viewModel.artistDetail {
                    NavigationLink(value: TopTracksDestination(
                        artistId: detail.id,
                        artistName: detail.name,
                        tracks: detail.tracks,
                        tracksBrowseId: detail.tracksBrowseId,
                        tracksParams: detail.tracksParams
                    )) {
                        Text(L("See all"))
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.accent)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(self.viewModel.displayedTracks.enumerated()), id: \.element.id) { index, track in
                    self.topTrackRow(track, index: index)

                    if index < self.viewModel.displayedTracks.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    /// Track row for top tracks section - fetches all tracks and plays as queue.
    private func topTrackRow(_ track: Track, index: Int) -> some View {
        Button {
            // Fetch all tracks and play as queue starting from the selected track
            Task {
                let allTracks = await self.viewModel.getAllTracks()
                // Find the index of the selected track in the full list
                let startIndex = allTracks.firstIndex(where: { $0.videoId == track.videoId }) ?? index
                await self.playbackStore.playQueue(allTracks, startingAt: startIndex)
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
                }
                .frame(width: 40, height: 40)
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
                        .frame(width: 150, alignment: .leading)
                } else {
                    Text("")
                        .frame(width: 150, alignment: .leading)
                }

                // Duration
                Text(track.durationDisplay)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task {
                    let allTracks = await self.viewModel.getAllTracks()
                    let startIndex = allTracks.firstIndex(where: { $0.videoId == track.videoId }) ?? index
                    await self.playbackStore.playQueue(allTracks, startingAt: startIndex)
                }
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

            // Go to Album - show if album has valid browse ID
            if let album = track.album, album.hasNavigableId {
                Divider()

                AlbumPlaybackContextMenu(
                    album: album,
                    client: self.viewModel.client,
                    playbackStore: self.playbackStore
                )

                Divider()

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

    private func albumsSection(_ albums: [Album]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Albums"))
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(value: self.playlistFromAlbum(album)) {
                            self.albumCard(album)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
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

                            NavigationLink(value: self.playlistFromAlbum(album)) {
                                Label(L("View Album"), systemImage: "square.stack")
                            }
                        }
                    }
                }
            }
        }
    }

    private func playlistFromAlbum(_ album: Album) -> Playlist {
        Playlist(
            id: album.id,
            title: album.title,
            description: nil,
            thumbnailURL: album.thumbnailURL,
            trackCount: album.trackCount,
            author: album.artistsDisplay
        )
    }

    private func albumCard(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            CachedAsyncImage(url: album.thumbnailURL?.highQualityThumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "square.stack")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 140, height: 140)
            .clipShape(.rect(cornerRadius: 8))

            // Title
            Text(album.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)

            // Year
            if let year = album.year {
                Text(year)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)
            }
        }
    }

    // MARK: - Actions

    private func playMix(playlistId: String, startVideoId: String?) {
        Task {
            await self.playbackStore.playWithMix(playlistId: playlistId, startVideoId: startVideoId)
        }
    }

    private func playAll(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        Task {
            await self.playbackStore.playQueue(tracks, startingAt: 0)
        }
    }

    /// Fetches all artist tracks and plays them shuffled.
    private func shuffleAllTracks() async {
        let allTracks = await self.viewModel.getAllTracks()
        guard !allTracks.isEmpty else { return }
        let shuffledTracks = allTracks.shuffled()
        await self.playbackStore.playQueue(shuffledTracks, startingAt: 0)
    }
}

#Preview {
    let artist = Artist(
        id: "test",
        name: "Test Artist",
        thumbnailURL: nil
    )
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    ArtistDetailView(
        artist: artist,
        viewModel: ArtistDetailViewModel(
            artist: artist,
            client: client
        )
    )
    .environment(PlaybackStore())
}
