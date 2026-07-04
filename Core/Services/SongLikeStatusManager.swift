import Foundation

// MARK: - TrackLikeStatusManager

/// Manages like/dislike status for tracks across the app.
/// This service caches like statuses locally and syncs with the YouTube Music API.
@MainActor
@Observable
final class TrackLikeStatusManager {
    /// Shared singleton instance.
    static let shared = TrackLikeStatusManager()

    /// Cache of video ID to like status.
    private var statusCache: [String: LikeStatus] = [:]

    /// Reference to the YTMusic client for API calls.
    private var client: (any YTMusicClientProtocol)?

    private init() {}

    // MARK: - Configuration

    /// Sets the client to use for API calls.
    /// - Parameter client: The YTMusic client.
    func setClient(_ client: any YTMusicClientProtocol) {
        self.client = client
    }

    // MARK: - Status Queries

    /// Gets the cached like status for a track.
    /// - Parameter videoId: The video ID of the track.
    /// - Returns: The cached status, or nil if not cached.
    func status(for videoId: String) -> LikeStatus? {
        self.statusCache[videoId]
    }

    /// Gets the like status for a track, using the track's own status as fallback.
    /// - Parameter track: The track to check.
    /// - Returns: The status from cache, track property, or nil.
    func status(for track: Track) -> LikeStatus? {
        self.statusCache[track.videoId] ?? track.likeStatus
    }

    /// Checks if a track is liked.
    /// - Parameter track: The track to check.
    /// - Returns: True if the track is liked.
    func isLiked(_ track: Track) -> Bool {
        self.status(for: track) == .like
    }

    /// Checks if a track is disliked.
    /// - Parameter track: The track to check.
    /// - Returns: True if the track is disliked.
    func isDisliked(_ track: Track) -> Bool {
        self.status(for: track) == .dislike
    }

    // MARK: - Rating Actions

    /// Likes a track.
    /// - Parameter track: The track to like.
    func like(_ track: Track) async {
        await self.rate(track, status: .like)
    }

    /// Unlikes a track (removes rating).
    /// - Parameter track: The track to unlike.
    func unlike(_ track: Track) async {
        await self.rate(track, status: .indifferent)
    }

    /// Dislikes a track.
    /// - Parameter track: The track to dislike.
    func dislike(_ track: Track) async {
        await self.rate(track, status: .dislike)
    }

    /// Undislikes a track (removes rating).
    /// - Parameter track: The track to undislike.
    func undislike(_ track: Track) async {
        await self.rate(track, status: .indifferent)
    }

    /// Rates a track with the given status.
    /// - Parameters:
    ///   - track: The track to rate.
    ///   - status: The rating to apply.
    private func rate(_ track: Track, status: LikeStatus) async {
        guard let client else {
            DiagnosticsLogger.api.warning("TrackLikeStatusManager: No client set, cannot rate track")
            return
        }

        // Optimistically update cache
        let previousStatus = self.statusCache[track.videoId]
        self.statusCache[track.videoId] = status

        do {
            try await client.rateTrack(videoId: track.videoId, rating: status)
            DiagnosticsLogger.api.info("Rated track \(track.videoId) as \(status.rawValue)")
        } catch is CancellationError {
            // Task was cancelled - rollback optimistic update
            if let previous = previousStatus {
                self.statusCache[track.videoId] = previous
            } else {
                self.statusCache.removeValue(forKey: track.videoId)
            }
            DiagnosticsLogger.api.debug("Rating cancelled for track \(track.videoId), rolled back")
        } catch {
            // Revert on failure
            if let previous = previousStatus {
                self.statusCache[track.videoId] = previous
            } else {
                self.statusCache.removeValue(forKey: track.videoId)
            }
            DiagnosticsLogger.api.error("Failed to rate track: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Management

    /// Updates the cache with a known status (e.g., from API response).
    /// - Parameters:
    ///   - videoId: The video ID.
    ///   - status: The like status.
    func setStatus(_ status: LikeStatus, for videoId: String) {
        self.statusCache[videoId] = status
    }

    /// Clears all cached statuses.
    func clearCache() {
        self.statusCache.removeAll()
    }
}
