import Foundation
import Testing
@testable import OptiTube

/// Tests for PlaybackStore+Library extension (like/dislike/library actions).
@Suite("PlaybackStore+Library", .serialized, .tags(.service))
@MainActor
struct PlaybackStoreLibraryTests {
    var playbackStore: PlaybackStore
    var mockClient: MockYTMusicClient

    init() {
        self.mockClient = MockYTMusicClient()
        self.playbackStore = PlaybackStore()
        self.playbackStore.setYTMusicClient(self.mockClient)
    }

    // MARK: - Like Current Track Tests

    @Test("likeCurrentTrack does nothing when no current track")
    func likeCurrentTrackNoTrack() async {
        #expect(self.playbackStore.currentTrack == nil)

        self.playbackStore.likeCurrentTrack()

        // Allow time for any async task to complete
        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackCalled == false)
    }

    @Test("likeCurrentTrack sets status to like when indifferent")
    func likeCurrentTrackSetsLike() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .indifferent

        self.playbackStore.likeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .like)

        // Wait for the async API call
        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackCalled == true)
        #expect(self.mockClient.rateTrackVideoIds.first == "test-video")
        #expect(self.mockClient.rateTrackRatings.first == .like)
    }

    @Test("likeCurrentTrack toggles to indifferent when already liked")
    func likeCurrentTrackTogglesOff() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .like

        self.playbackStore.likeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackRatings.first == .indifferent)
    }

    @Test("likeCurrentTrack changes dislike to like")
    func likeCurrentTrackFromDislike() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .dislike

        self.playbackStore.likeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .like)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackRatings.first == .like)
    }

    @Test("likeCurrentTrack reverts on API failure")
    func likeCurrentTrackRevertsOnFailure() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .indifferent
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        self.playbackStore.likeCurrentTrack()

        // Optimistic update should happen immediately
        #expect(self.playbackStore.currentTrackLikeStatus == .like)

        // Wait for the async API call to fail and revert
        try? await Task.sleep(for: .milliseconds(100))

        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)
    }

    // MARK: - Dislike Current Track Tests

    @Test("dislikeCurrentTrack does nothing when no current track")
    func dislikeCurrentTrackNoTrack() async {
        #expect(self.playbackStore.currentTrack == nil)

        self.playbackStore.dislikeCurrentTrack()

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackCalled == false)
    }

    @Test("dislikeCurrentTrack sets status to dislike when indifferent")
    func dislikeCurrentTrackSetsDislike() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .indifferent

        self.playbackStore.dislikeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .dislike)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackCalled == true)
        #expect(self.mockClient.rateTrackRatings.first == .dislike)
    }

    @Test("dislikeCurrentTrack toggles to indifferent when already disliked")
    func dislikeCurrentTrackTogglesOff() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .dislike

        self.playbackStore.dislikeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackRatings.first == .indifferent)
    }

    @Test("dislikeCurrentTrack changes like to dislike")
    func dislikeCurrentTrackFromLike() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .like

        self.playbackStore.dislikeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .dislike)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.rateTrackRatings.first == .dislike)
    }

    @Test("dislikeCurrentTrack reverts on API failure")
    func dislikeCurrentTrackRevertsOnFailure() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackLikeStatus = .indifferent
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        self.playbackStore.dislikeCurrentTrack()

        #expect(self.playbackStore.currentTrackLikeStatus == .dislike)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)
    }

    // MARK: - Toggle Library Status Tests

    @Test("toggleLibraryStatus does nothing when no current track")
    func toggleLibraryStatusNoTrack() async {
        #expect(self.playbackStore.currentTrack == nil)

        self.playbackStore.toggleLibraryStatus()

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.editTrackLibraryStatusCalled == false)
    }

    @Test("toggleLibraryStatus does nothing when no feedback token")
    func toggleLibraryStatusNoToken() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackFeedbackTokens = nil

        self.playbackStore.toggleLibraryStatus()

        try? await Task.sleep(for: .milliseconds(50))

        #expect(self.mockClient.editTrackLibraryStatusCalled == false)
    }

    @Test("toggleLibraryStatus adds to library when not in library")
    func toggleLibraryStatusAddsToLibrary() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackInLibrary = false
        self.playbackStore.currentTrackFeedbackTokens = FeedbackTokens(add: "add-token", remove: "remove-token")

        self.playbackStore.toggleLibraryStatus()

        #expect(self.playbackStore.currentTrackInLibrary == true)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(self.mockClient.editTrackLibraryStatusCalled == true)
        #expect(self.mockClient.editTrackLibraryStatusTokens.first?.first == "add-token")
    }

    @Test("toggleLibraryStatus removes from library when in library")
    func toggleLibraryStatusRemovesFromLibrary() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackInLibrary = true
        self.playbackStore.currentTrackFeedbackTokens = FeedbackTokens(add: "add-token", remove: "remove-token")

        self.playbackStore.toggleLibraryStatus()

        #expect(self.playbackStore.currentTrackInLibrary == false)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(self.mockClient.editTrackLibraryStatusCalled == true)
        #expect(self.mockClient.editTrackLibraryStatusTokens.first?.first == "remove-token")
    }

    @Test("toggleLibraryStatus reverts on API failure")
    func toggleLibraryStatusRevertsOnFailure() async {
        self.playbackStore.currentTrack = TestFixtures.makeTrack(id: "test-video")
        self.playbackStore.currentTrackInLibrary = false
        self.playbackStore.currentTrackFeedbackTokens = FeedbackTokens(add: "add-token", remove: "remove-token")
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        self.playbackStore.toggleLibraryStatus()

        #expect(self.playbackStore.currentTrackInLibrary == true)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(self.playbackStore.currentTrackInLibrary == false)
    }

    // MARK: - Update Like Status Tests

    @Test("updateLikeStatus updates status")
    func updateLikeStatus() {
        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)

        self.playbackStore.updateLikeStatus(.like)
        #expect(self.playbackStore.currentTrackLikeStatus == .like)

        self.playbackStore.updateLikeStatus(.dislike)
        #expect(self.playbackStore.currentTrackLikeStatus == .dislike)

        self.playbackStore.updateLikeStatus(.indifferent)
        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)
    }

    // MARK: - Reset Track Status Tests

    @Test("resetTrackStatus resets all status properties")
    func resetTrackStatus() {
        self.playbackStore.currentTrackLikeStatus = .like
        self.playbackStore.currentTrackInLibrary = true
        self.playbackStore.currentTrackFeedbackTokens = FeedbackTokens(add: "add", remove: "remove")

        self.playbackStore.resetTrackStatus()

        #expect(self.playbackStore.currentTrackLikeStatus == .indifferent)
        #expect(self.playbackStore.currentTrackInLibrary == false)
        #expect(self.playbackStore.currentTrackFeedbackTokens == nil)
    }
}
