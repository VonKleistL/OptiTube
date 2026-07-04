import Foundation
import Testing

@testable import OptiTube

@Suite("TopTracksViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct TopTracksViewModelTests {
    // MARK: - Initial State Tests

    @Test("Initial state includes tracks from destination")
    func initialStateIncludesTracksFromDestination() {
        let mockClient = MockYTMusicClient()
        let tracks = [
            TestFixtures.makeTrack(videoId: "track-1", title: "Track 1"),
            TestFixtures.makeTrack(videoId: "track-2", title: "Track 2"),
        ]
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: tracks,
            tracksBrowseId: nil,
            tracksParams: nil
        )

        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        #expect(viewModel.loadingState == .idle)
        #expect(viewModel.tracks.count == 2)
        #expect(viewModel.tracks[0].title == "Track 1")
        #expect(viewModel.tracks[1].title == "Track 2")
    }

    // MARK: - Load Without Browse ID Tests

    @Test("Load without browse ID immediately sets loaded state")
    func loadWithoutBrowseIdSetsLoadedImmediately() async {
        let mockClient = MockYTMusicClient()
        let tracks = [TestFixtures.makeTrack(videoId: "track-1", title: "Initial")]
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: tracks,
            tracksBrowseId: nil,
            tracksParams: nil
        )
        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        await viewModel.load()

        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.tracks.count == 1)
        #expect(mockClient.getArtistTracksCalled == false)
    }

    // MARK: - Load With Browse ID Tests

    @Test("Load with browse ID fetches all tracks")
    func loadWithBrowseIdFetchesAllTracks() async {
        let mockClient = MockYTMusicClient()
        let initialTracks = [TestFixtures.makeTrack(videoId: "track-1", title: "Initial")]
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: initialTracks,
            tracksBrowseId: "browse-id-123",
            tracksParams: "params-abc"
        )
        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        mockClient.artistTracksResponse = [
            TestFixtures.makeTrack(videoId: "track-1", title: "Track 1"),
            TestFixtures.makeTrack(videoId: "track-2", title: "Track 2"),
            TestFixtures.makeTrack(videoId: "track-3", title: "Track 3"),
        ]

        await viewModel.load()

        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.tracks.count == 3)
        #expect(mockClient.getArtistTracksCalled)
        #expect(mockClient.getArtistTracksBrowseIds.contains("browse-id-123"))
    }

    @Test("Load with browse ID keeps initial tracks on error")
    func loadWithBrowseIdKeepsInitialTracksOnError() async {
        let mockClient = MockYTMusicClient()
        let initialTracks = [
            TestFixtures.makeTrack(videoId: "track-1", title: "Initial 1"),
            TestFixtures.makeTrack(videoId: "track-2", title: "Initial 2"),
        ]
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: initialTracks,
            tracksBrowseId: "browse-id-123",
            tracksParams: nil
        )
        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        mockClient.shouldThrowError = YTMusicError.networkError(
            underlying: URLError(.notConnectedToInternet)
        )

        await viewModel.load()

        // Should still be loaded with initial tracks preserved
        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.tracks.count == 2)
        #expect(viewModel.tracks[0].title == "Initial 1")
    }

    @Test("Load with browse ID keeps initial tracks when API returns empty")
    func loadWithBrowseIdKeepsInitialTracksWhenEmpty() async {
        let mockClient = MockYTMusicClient()
        let initialTracks = [TestFixtures.makeTrack(videoId: "track-1", title: "Initial")]
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: initialTracks,
            tracksBrowseId: "browse-id-123",
            tracksParams: nil
        )
        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        mockClient.artistTracksResponse = []

        await viewModel.load()

        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.tracks.count == 1)
        #expect(viewModel.tracks[0].title == "Initial")
    }

    @Test("Load does not run concurrently when already loading")
    func loadPreventsConncurrentCalls() async {
        let mockClient = MockYTMusicClient()
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: [],
            tracksBrowseId: "browse-id-123",
            tracksParams: nil
        )
        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        mockClient.artistTracksResponse = [TestFixtures.makeTrack(videoId: "track-1", title: "Track 1")]
        mockClient.apiDelay = 0.1

        // Start first load
        let task1 = Task {
            await viewModel.load()
        }

        // Try to start another load immediately
        try? await Task.sleep(for: .milliseconds(20))
        let task2 = Task {
            await viewModel.load()
        }

        await task1.value
        await task2.value

        #expect(viewModel.loadingState == .loaded)
    }

    // MARK: - Client Exposure Tests

    @Test("Client is exposed for playback")
    func clientIsExposed() {
        let mockClient = MockYTMusicClient()
        let destination = TopTracksDestination(
            artistName: "Test Artist",
            tracks: [],
            tracksBrowseId: nil,
            tracksParams: nil
        )
        let viewModel = TopTracksViewModel(destination: destination, client: mockClient)

        #expect(viewModel.client is MockYTMusicClient)
    }
}
