import Foundation
import Testing
@testable import OptiTube

/// Tests for TrackLikeStatusManager.
@Suite("TrackLikeStatusManager", .serialized, .tags(.service))
@MainActor
struct TrackLikeStatusManagerTests {
    var manager: TrackLikeStatusManager
    var mockClient: MockYTMusicClient

    init() {
        // Create a fresh instance for each test (not the shared singleton)
        self.manager = TrackLikeStatusManager()
        self.mockClient = MockYTMusicClient()
        self.manager.setClient(self.mockClient)
    }

    // MARK: - Status Query Tests

    @Test("status for videoId returns nil when not cached")
    func statusForVideoIdReturnsNilWhenNotCached() {
        let status = self.manager.status(for: "unknown-video")
        #expect(status == nil)
    }

    @Test("status for videoId returns cached value")
    func statusForVideoIdReturnsCached() {
        self.manager.setStatus(.like, for: "test-video")

        let status = self.manager.status(for: "test-video")

        #expect(status == .like)
    }

    @Test("status for track uses cache over track property")
    func statusForTrackUsesCacheOverProperty() {
        let track = Track(
            id: "test-video",
            title: "Test",
            artists: [],
            videoId: "test-video",
            likeStatus: .dislike
        )
        self.manager.setStatus(.like, for: "test-video")

        let status = self.manager.status(for: track)

        #expect(status == .like) // Cache takes precedence
    }

    @Test("status for track falls back to track property")
    func statusForTrackFallsBackToProperty() {
        let track = Track(
            id: "test-video",
            title: "Test",
            artists: [],
            videoId: "test-video",
            likeStatus: .dislike
        )
        // No cache set

        let status = self.manager.status(for: track)

        #expect(status == .dislike)
    }

    @Test("isLiked returns true when liked")
    func isLikedReturnsTrue() {
        let track = TestFixtures.makeTrack(id: "test-video")
        self.manager.setStatus(.like, for: "test-video")

        #expect(self.manager.isLiked(track) == true)
        #expect(self.manager.isDisliked(track) == false)
    }

    @Test("isDisliked returns true when disliked")
    func isDislikedReturnsTrue() {
        let track = TestFixtures.makeTrack(id: "test-video")
        self.manager.setStatus(.dislike, for: "test-video")

        #expect(self.manager.isDisliked(track) == true)
        #expect(self.manager.isLiked(track) == false)
    }

    // MARK: - Rating Action Tests

    @Test("like updates cache and calls API")
    func likeUpdatesCacheAndCallsAPI() async {
        let track = TestFixtures.makeTrack(id: "test-video")

        await self.manager.like(track)

        #expect(self.manager.status(for: "test-video") == .like)
        #expect(self.mockClient.rateTrackCalled == true)
        #expect(self.mockClient.rateTrackVideoIds.first == "test-video")
        #expect(self.mockClient.rateTrackRatings.first == .like)
    }

    @Test("unlike updates cache to indifferent")
    func unlikeUpdatesCacheToIndifferent() async {
        let track = TestFixtures.makeTrack(id: "test-video")
        self.manager.setStatus(.like, for: "test-video")

        await self.manager.unlike(track)

        #expect(self.manager.status(for: "test-video") == .indifferent)
        #expect(self.mockClient.rateTrackRatings.first == .indifferent)
    }

    @Test("dislike updates cache and calls API")
    func dislikeUpdatesCacheAndCallsAPI() async {
        let track = TestFixtures.makeTrack(id: "test-video")

        await self.manager.dislike(track)

        #expect(self.manager.status(for: "test-video") == .dislike)
        #expect(self.mockClient.rateTrackRatings.first == .dislike)
    }

    @Test("undislike updates cache to indifferent")
    func undislikeUpdatesCacheToIndifferent() async {
        let track = TestFixtures.makeTrack(id: "test-video")
        self.manager.setStatus(.dislike, for: "test-video")

        await self.manager.undislike(track)

        #expect(self.manager.status(for: "test-video") == .indifferent)
    }

    // MARK: - Error Handling Tests

    @Test("like reverts cache on API failure")
    func likeRevertsCacheOnFailure() async {
        let track = TestFixtures.makeTrack(id: "test-video")
        self.manager.setStatus(.indifferent, for: "test-video")
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.manager.like(track)

        // Should revert to previous status
        #expect(self.manager.status(for: "test-video") == .indifferent)
    }

    @Test("like removes cache entry on failure when no previous")
    func likeRemovesCacheOnFailureWhenNoPrevious() async {
        let track = TestFixtures.makeTrack(id: "new-video")
        // No previous status set
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.manager.like(track)

        // Should remove the entry entirely
        #expect(self.manager.status(for: "new-video") == nil)
    }

    @Test("dislike reverts cache on API failure")
    func dislikeRevertsCacheOnFailure() async {
        let track = TestFixtures.makeTrack(id: "test-video")
        self.manager.setStatus(.like, for: "test-video")
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.manager.dislike(track)

        // Should revert to previous status
        #expect(self.manager.status(for: "test-video") == .like)
    }

    @Test("rating without client does nothing")
    func ratingWithoutClientDoesNothing() async {
        let managerWithoutClient = TrackLikeStatusManager()
        let track = TestFixtures.makeTrack(id: "test-video")

        await managerWithoutClient.like(track)

        // Status should not be set since there's no client
        #expect(managerWithoutClient.status(for: "test-video") == nil)
    }

    // MARK: - Cache Management Tests

    @Test("setStatus updates cache")
    func setStatusUpdatesCache() {
        self.manager.setStatus(.like, for: "video-1")
        self.manager.setStatus(.dislike, for: "video-2")

        #expect(self.manager.status(for: "video-1") == .like)
        #expect(self.manager.status(for: "video-2") == .dislike)
    }

    @Test("clearCache removes all entries")
    func clearCacheRemovesAllEntries() {
        self.manager.setStatus(.like, for: "video-1")
        self.manager.setStatus(.dislike, for: "video-2")

        self.manager.clearCache()

        #expect(self.manager.status(for: "video-1") == nil)
        #expect(self.manager.status(for: "video-2") == nil)
    }
}
