import SwiftUI

// MARK: - YouTubeContentView

/// Main detail column for the YouTube video mode.
///
/// Receives a `YouTubeViewModel` which owns all feed loading, search,
/// and pagination state. This view is purely presentational.
@available(macOS 15.0, *)
struct YouTubeContentView: View {
    @Bindable var viewModel: YouTubeViewModel
    let selection: YouTubeNavigationItem?

    @Environment(YouTubePlayerService.self) private var youtubePlayer

    var body: some View {
        VStack(spacing: 0) {
            if let currentVideo = self.youtubePlayer.currentVideo {
                self.playerView(for: currentVideo)
            } else {
                self.explorerView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: selection) {
            guard let item = selection else { return }
            await self.viewModel.load(selection: item)
        }
    }

    // MARK: - Player View

    @ViewBuilder
    private func playerView(for video: YouTubeVideo) -> some View {
        VStack(spacing: 12) {
            // Header bar
            HStack {
                Button {
                    self.youtubePlayer.stop()
                } label: {
                    Label(L("Back"), systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.pressable)
                .foregroundStyle(.primary)

                Spacer()

                Text(video.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    self.youtubePlayer.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.pressable)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Full YouTube watch page: video, likes, comments, and related videos.
            YouTubeWatchSurfaceView()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Explorer View

    @ViewBuilder
    private var explorerView: some View {
        VStack(spacing: 0) {
            // Top bar: title + search bar
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(self.viewModel.selection.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Refresh button
                    Button {
                        Task { await self.viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.pressable)
                    .disabled(self.viewModel.loadingState == .loading)
                }

                YouTubeSearchBar(viewModel: self.viewModel)

                // Filter bar (only during search)
                if self.viewModel.isSearchMode {
                    YouTubeFilterBar(viewModel: self.viewModel)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.3)

            // Content area
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    self.contentBody
                }
                .padding(.all, 24)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: self.viewModel.isSearchMode)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch self.viewModel.loadingState {
        case .loading:
            self.loadingView

        case let .error(err):
            self.errorView(message: err.message)

        case .authRequired:
            self.authRequiredView

        case .idle, .loaded, .loadingMore:
            if self.viewModel.isSearchMode {
                self.searchResultsView
            } else {
                self.feedSectionsView
            }
        }
    }

    // MARK: - Feed Sections

    @ViewBuilder
    private var feedSectionsView: some View {
        if self.viewModel.sections.isEmpty, self.viewModel.loadingState == .idle {
            // Nothing loaded yet — placeholder
            self.loadingView
        } else if self.viewModel.sections.isEmpty {
            self.emptyView
        } else {
            ForEach(self.viewModel.sections) { section in
                YouTubeFeedSectionView(
                    section: section,
                    onPlayVideo: { video in
                        self.viewModel.play(video)
                    },
                    onOpenPlaylist: { playlist in
                        self.viewModel.openPlaylist(playlist)
                    },
                    onOpenChannel: { channel in
                        self.viewModel.openChannel(channel)
                    }
                )
            }

            // Infinite scroll / load more
            self.loadMoreArea
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsView: some View {
        if self.viewModel.searchResults.isEmpty, self.viewModel.loadingState != .idle {
            self.emptyView
        } else {
            let columns = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 16)]

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(self.viewModel.searchResults) { item in
                    switch item {
                    case let .video(video):
                        YouTubeVideoCard(video: video) {
                            self.viewModel.play(video)
                        }
                    case let .playlist(playlist):
                        YouTubePlaylistCard(playlist: playlist) { tapped in
                            self.viewModel.openPlaylist(tapped)
                        }
                    case let .channel(channel):
                        YouTubeChannelCard(channel: channel) { tapped in
                            self.viewModel.openChannel(tapped)
                        }
                    }
                }
            }

            self.loadMoreArea
        }
    }

    // MARK: - Load More Area

    @ViewBuilder
    private var loadMoreArea: some View {
        if self.viewModel.continuationToken != nil {
            HStack {
                Spacer()
                if self.viewModel.isLoadingMore {
                    ProgressView()
                }
                Spacer()
            }
            .frame(height: 48)
            .task(id: self.viewModel.continuationToken) {
                await self.viewModel.loadMore()
            }
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading…")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Something went wrong")
                .font(.system(size: 16, weight: .semibold))

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                Task { await self.viewModel.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.appAccent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No results")
                .font(.system(size: 16, weight: .semibold))
            Text("Try a different search or sign in if needed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var authRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Sign in to YouTube")
                    .font(.system(size: 18, weight: .semibold))

                Text("This section requires a signed-in YouTube account. Switch to Music mode and sign in via the profile button, then return here.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button {
                Task { await self.viewModel.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.appAccent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
