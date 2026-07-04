import Foundation
import Testing
@testable import OptiTube

/// Tests for ArtistDetailViewModel using mock client.
@Suite("ArtistDetailViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct ArtistDetailViewModelTests {
    var mockClient: MockYTMusicClient
    var viewModel: ArtistDetailViewModel

    init() {
        self.mockClient = MockYTMusicClient()
        let artist = TestFixtures.makeArtist(id: "UC-test-artist", name: "Test Artist")
        self.viewModel = ArtistDetailViewModel(artist: artist, client: self.mockClient)
    }

    // MARK: - Initial State Tests

    @Test("Initial state is idle with no artist detail")
    func initialState() {
        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.artistDetail == nil)
        #expect(self.viewModel.showAllTracks == false)
    }

    // MARK: - Load Tests

    @Test("Load success sets artist detail")
    func loadSuccess() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 10,
            albumCount: 3
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()

        #expect(self.mockClient.getArtistCalled == true)
        #expect(self.mockClient.getArtistIds.first == "UC-test-artist")
        #expect(self.viewModel.loadingState == .loaded)
        #expect(self.viewModel.artistDetail != nil)
        #expect(self.viewModel.artistDetail?.tracks.count == 10)
        #expect(self.viewModel.artistDetail?.albums.count == 3)
    }

    @Test("Load error sets error state")
    func loadError() async {
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.viewModel.load()

        #expect(self.mockClient.getArtistCalled == true)
        if case let .error(error) = viewModel.loadingState {
            #expect(!error.message.isEmpty)
            #expect(error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
        #expect(self.viewModel.artistDetail == nil)
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 5
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        await self.viewModel.load()

        #expect(self.viewModel.loadingState == .loaded)
    }

    @Test("Load uses original artist info for unknown name")
    func loadUsesOriginalArtistInfoForUnknownName() async {
        // Create an artist detail with "Unknown Artist" name
        let unknownArtist = Artist(
            id: "UC-test-artist",
            name: "Unknown Artist",
            thumbnailURL: nil
        )
        let artistDetail = ArtistDetail(
            artist: unknownArtist,
            description: nil,
            tracks: TestFixtures.makeTracks(count: 3),
            albums: [],
            thumbnailURL: nil
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()

        // Should use original artist name "Test Artist" instead of "Unknown Artist"
        #expect(self.viewModel.artistDetail?.name == "Test Artist")
    }

    // MARK: - Refresh Tests

    @Test("Refresh clears detail and reloads")
    func refreshClearsDetailAndReloads() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 5
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        #expect(self.viewModel.artistDetail?.tracks.count == 5)

        // Update mock to return different track count
        let newArtistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 8
        )
        self.mockClient.artistDetails["UC-test-artist"] = newArtistDetail

        await self.viewModel.refresh()

        #expect(self.viewModel.artistDetail?.tracks.count == 8)
        #expect(self.viewModel.showAllTracks == false)
    }

    // MARK: - Displayed Tracks Tests

    @Test("displayedTracks returns preview count by default")
    func displayedTracksReturnsPreviewCount() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 10
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()

        #expect(self.viewModel.displayedTracks.count == ArtistDetailViewModel.previewTrackCount)
    }

    @Test("displayedTracks returns all tracks when showAllTracks is true")
    func displayedTracksReturnsAllWhenShowAllTracks() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 10
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        self.viewModel.showAllTracks = true

        #expect(self.viewModel.displayedTracks.count == 10)
    }

    @Test("displayedTracks returns empty when no detail")
    func displayedTracksReturnsEmptyWhenNoDetail() {
        #expect(self.viewModel.displayedTracks.isEmpty)
    }

    // MARK: - Has More Tracks Tests

    @Test("hasMoreTracks returns false when no detail")
    func hasMoreTracksReturnsFalseWhenNoDetail() {
        #expect(self.viewModel.hasMoreTracks == false)
    }

    @Test("hasMoreTracks returns true when tracks exceed preview count")
    func hasMoreTracksReturnsTrueWhenExceedsPreview() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 10 // More than previewTrackCount
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()

        #expect(self.viewModel.hasMoreTracks == true)
    }

    @Test("hasMoreTracks returns false when tracks within preview count")
    func hasMoreTracksReturnsFalseWhenWithinPreview() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 3 // Less than previewTrackCount
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()

        #expect(self.viewModel.hasMoreTracks == false)
    }

    // MARK: - Subscription Tests

    @Test("toggleSubscription does nothing without channel ID")
    func toggleSubscriptionNoChannelId() async {
        let artistDetail = ArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            description: nil,
            tracks: [],
            albums: [],
            thumbnailURL: nil,
            channelId: nil // No channel ID
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        await self.viewModel.toggleSubscription()

        #expect(self.mockClient.subscribeToArtistCalled == false)
        #expect(self.mockClient.unsubscribeFromArtistCalled == false)
    }

    @Test("toggleSubscription subscribes when not subscribed")
    func toggleSubscriptionSubscribes() async {
        let artistDetail = ArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            description: nil,
            tracks: [],
            albums: [],
            thumbnailURL: nil,
            channelId: "UC-channel-123",
            isSubscribed: false
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        await self.viewModel.toggleSubscription()

        #expect(self.mockClient.subscribeToArtistCalled == true)
        #expect(self.mockClient.subscribeToArtistIds.first == "UC-channel-123")
        #expect(self.viewModel.artistDetail?.isSubscribed == true)
    }

    @Test("toggleSubscription unsubscribes when subscribed")
    func toggleSubscriptionUnsubscribes() async {
        let artistDetail = ArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            description: nil,
            tracks: [],
            albums: [],
            thumbnailURL: nil,
            channelId: "UC-channel-123",
            isSubscribed: true
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        await self.viewModel.toggleSubscription()

        #expect(self.mockClient.unsubscribeFromArtistCalled == true)
        #expect(self.mockClient.unsubscribeFromArtistIds.first == "UC-channel-123")
        #expect(self.viewModel.artistDetail?.isSubscribed == false)
    }

    @Test("toggleSubscription sets error on failure")
    func toggleSubscriptionSetsErrorOnFailure() async {
        let artistDetail = ArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            description: nil,
            tracks: [],
            albums: [],
            thumbnailURL: nil,
            channelId: "UC-channel-123",
            isSubscribed: false
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.viewModel.toggleSubscription()

        #expect(self.viewModel.subscriptionError != nil)
        #expect(self.viewModel.artistDetail?.isSubscribed == false) // Unchanged
    }

    // MARK: - Get All Tracks Tests

    @Test("getAllTracks returns artist detail tracks when no browse ID")
    func getAllTracksReturnsDetailTracks() async {
        let artistDetail = TestFixtures.makeArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            trackCount: 5
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail

        await self.viewModel.load()
        let tracks = await self.viewModel.getAllTracks()

        #expect(tracks.count == 5)
        #expect(self.mockClient.getArtistTracksCalled == false)
    }

    @Test("getAllTracks fetches from API when browse ID available")
    func getAllTracksFetchesFromAPI() async {
        let artistDetail = ArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            description: nil,
            tracks: TestFixtures.makeTracks(count: 5),
            albums: [],
            thumbnailURL: nil,
            hasMoreTracks: true,
            tracksBrowseId: "artist-tracks-browse-id"
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail
        self.mockClient.artistTracks["artist-tracks-browse-id"] = TestFixtures.makeTracks(count: 20)

        await self.viewModel.load()
        let tracks = await self.viewModel.getAllTracks()

        #expect(tracks.count == 20)
        #expect(self.mockClient.getArtistTracksCalled == true)
        #expect(self.mockClient.getArtistTracksBrowseIds.first == "artist-tracks-browse-id")
    }

    @Test("getAllTracks returns cached tracks on subsequent calls")
    func getAllTracksReturnsCached() async {
        let artistDetail = ArtistDetail(
            artist: TestFixtures.makeArtist(id: "UC-test-artist"),
            description: nil,
            tracks: TestFixtures.makeTracks(count: 5),
            albums: [],
            thumbnailURL: nil,
            hasMoreTracks: true,
            tracksBrowseId: "artist-tracks-browse-id"
        )
        self.mockClient.artistDetails["UC-test-artist"] = artistDetail
        self.mockClient.artistTracks["artist-tracks-browse-id"] = TestFixtures.makeTracks(count: 20)

        await self.viewModel.load()
        _ = await self.viewModel.getAllTracks()
        _ = await self.viewModel.getAllTracks()

        // Should only call API once
        #expect(self.mockClient.getArtistTracksBrowseIds.count == 1)
    }
}
