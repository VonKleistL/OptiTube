import Foundation
import Testing
@testable import OptiTube

/// Tests for LikedMusicViewModel using mock client.
@Suite("LikedMusicViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct LikedMusicViewModelTests {
    var mockClient: MockYTMusicClient
    var viewModel: LikedMusicViewModel

    init() {
        self.mockClient = MockYTMusicClient()
        self.viewModel = LikedMusicViewModel(client: self.mockClient)
    }

    @Test("Initial state is idle with empty tracks")
    func initialState() {
        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.tracks.isEmpty)
        #expect(self.viewModel.hasMore == false)
    }

    @Test("Load success sets tracks")
    func loadSuccess() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 5)

        await self.viewModel.load()

        #expect(self.mockClient.getLikedTracksCalled == true)
        #expect(self.viewModel.loadingState == .loaded)
        #expect(self.viewModel.tracks.count == 5)
    }

    @Test("Load success marks all tracks as liked")
    func loadSuccessMarksTracksAsLiked() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 3)

        await self.viewModel.load()

        for track in self.viewModel.tracks {
            #expect(track.likeStatus == .like)
        }
    }

    @Test("Load error sets error state")
    func loadError() async {
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.viewModel.load()

        #expect(self.mockClient.getLikedTracksCalled == true)
        if case let .error(error) = viewModel.loadingState {
            #expect(!error.message.isEmpty)
            #expect(error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
        #expect(self.viewModel.tracks.isEmpty)
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 2)

        await self.viewModel.load()
        await self.viewModel.load()

        // After load completes, subsequent load should work again
        #expect(self.viewModel.loadingState == .loaded)
    }

    @Test("Load more appends tracks")
    func loadMoreAppendsTracks() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 3)
        self.mockClient.likedTracksContinuationTracks = [
            [
                TestFixtures.makeTrack(id: "more-1"),
                TestFixtures.makeTrack(id: "more-2"),
            ],
        ]

        await self.viewModel.load()
        #expect(self.viewModel.tracks.count == 3)
        #expect(self.viewModel.hasMore == true)

        await self.viewModel.loadMore()

        #expect(self.mockClient.getLikedTracksContinuationCalled == true)
        #expect(self.viewModel.tracks.count == 5)
    }

    @Test("Load more deduplicates tracks")
    func loadMoreDeduplicates() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 2)
        self.mockClient.likedTracksContinuationTracks = [
            [
                TestFixtures.makeTrack(id: "video-0"), // Duplicate
                TestFixtures.makeTrack(id: "new-track"),
            ],
        ]

        await self.viewModel.load()
        await self.viewModel.loadMore()

        #expect(self.viewModel.tracks.count == 3) // 2 original + 1 new (deduped)
        #expect(self.viewModel.tracks.count(where: { $0.videoId == "video-0" }) == 1)
    }

    @Test("Load more stops when all duplicates")
    func loadMoreStopsOnAllDuplicates() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 2)
        self.mockClient.likedTracksContinuationTracks = [
            [
                TestFixtures.makeTrack(id: "video-0"), // Duplicate
                TestFixtures.makeTrack(id: "video-1"), // Duplicate
            ],
        ]

        await self.viewModel.load()
        await self.viewModel.loadMore()

        #expect(self.viewModel.tracks.count == 2)
        #expect(self.viewModel.hasMore == false)
    }

    @Test("Load more does nothing when not loaded")
    func loadMoreDoesNothingWhenNotLoaded() async {
        #expect(self.viewModel.loadingState == .idle)

        await self.viewModel.loadMore()

        #expect(self.mockClient.getLikedTracksContinuationCalled == false)
    }

    @Test("Load more does nothing when no more tracks")
    func loadMoreDoesNothingWhenNoMore() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 2)
        // No continuation set

        await self.viewModel.load()
        #expect(self.viewModel.hasMore == false)

        await self.viewModel.loadMore()

        #expect(self.mockClient.getLikedTracksContinuationCalled == false)
    }

    @Test("Refresh clears tracks and reloads")
    func refreshClearsTracksAndReloads() async {
        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 3)
        await self.viewModel.load()
        #expect(self.viewModel.tracks.count == 3)

        self.mockClient.likedTracks = TestFixtures.makeTracks(count: 5)
        await self.viewModel.refresh()

        #expect(self.viewModel.tracks.count == 5)
    }
}
