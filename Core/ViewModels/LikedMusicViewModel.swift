import Foundation
import Observation

/// View model for the Liked Music view.
@MainActor
@Observable
final class LikedMusicViewModel {
    /// Current loading state.
    private(set) var loadingState: LoadingState = .idle

    /// Liked tracks.
    private(set) var tracks: [Track] = []

    /// Whether more tracks are available to load.
    private(set) var hasMore: Bool = false

    /// The API client.
    let client: any YTMusicClientProtocol
    private let logger = DiagnosticsLogger.api

    init(client: any YTMusicClientProtocol) {
        self.client = client
    }

    /// Loads liked tracks.
    func load() async {
        guard self.loadingState != .loading else { return }

        self.loadingState = .loading
        self.logger.info("Loading liked tracks")

        do {
            let response = try await client.getLikedTracks()
            // Mark all tracks as liked since they come from the liked tracks API
            self.tracks = response.tracks.map { track in
                var mutableTrack = track
                mutableTrack.likeStatus = .like
                return mutableTrack
            }
            self.hasMore = response.hasMore
            // Also populate the like status manager cache
            for track in self.tracks {
                TrackLikeStatusManager.shared.setStatus(.like, for: track.videoId)
            }
            self.loadingState = .loaded
            self.logger.info("Loaded \(response.tracks.count) liked tracks, hasMore: \(self.hasMore)")
        } catch is CancellationError {
            // Task was cancelled (e.g., user navigated away) — reset to idle so it can retry
            self.logger.debug("Liked tracks load cancelled")
            self.loadingState = .idle
        } catch {
            self.logger.error("Failed to load liked tracks: \(error.localizedDescription)")
            self.loadingState = .error(LoadingError(from: error))
        }
    }

    /// Loads more liked tracks via continuation.
    func loadMore() async {
        guard self.loadingState == .loaded, self.hasMore else { return }

        self.loadingState = .loadingMore
        self.logger.info("Loading more liked tracks")

        do {
            guard let response = try await client.getLikedTracksContinuation() else {
                self.hasMore = false
                self.loadingState = .loaded
                return
            }

            // Build a set of existing video IDs for deduplication
            let existingVideoIds = Set(self.tracks.map(\.videoId))

            // Filter out duplicates and mark all tracks as liked
            let newTracks = response.tracks
                .filter { !existingVideoIds.contains($0.videoId) }
                .map { track in
                    var mutableTrack = track
                    mutableTrack.likeStatus = .like
                    return mutableTrack
                }

            // If no new unique tracks were added, stop pagination
            if newTracks.isEmpty {
                self.hasMore = false
                self.loadingState = .loaded
                self.logger.info("No new unique tracks in continuation, stopping pagination")
                return
            }

            self.tracks.append(contentsOf: newTracks)
            self.hasMore = response.hasMore

            // Populate the like status manager cache
            for track in newTracks {
                TrackLikeStatusManager.shared.setStatus(.like, for: track.videoId)
            }

            self.loadingState = .loaded
            self.logger.info("Loaded \(newTracks.count) new liked tracks (from \(response.tracks.count)), total: \(self.tracks.count), hasMore: \(self.hasMore)")
        } catch is CancellationError {
            self.logger.debug("Liked tracks continuation cancelled")
            self.loadingState = .loaded
        } catch {
            self.logger.error("Failed to load more liked tracks: \(error.localizedDescription)")
            // Keep loaded state so user can retry
            self.loadingState = .loaded
        }
    }

    /// Refreshes liked tracks.
    func refresh() async {
        self.tracks = []
        self.hasMore = false
        await self.load()
    }
}
