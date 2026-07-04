import Foundation
@testable import OptiTube

/// A mock implementation of YTMusicClientProtocol for testing.
@MainActor
final class MockYTMusicClient: YTMusicClientProtocol {
    // MARK: - Response Stubs

    var homeResponse: HomeResponse = .init(sections: [])
    var homeContinuationSections: [[HomeSection]] = []
    var exploreResponse: HomeResponse = .init(sections: [])
    var exploreContinuationSections: [[HomeSection]] = []
    var chartsResponse: HomeResponse = .init(sections: [])
    var chartsContinuationSections: [[HomeSection]] = []
    var moodsAndGenresResponse: HomeResponse = .init(sections: [])
    var moodsAndGenresContinuationSections: [[HomeSection]] = []
    var newReleasesResponse: HomeResponse = .init(sections: [])
    var newReleasesContinuationSections: [[HomeSection]] = []
    var podcastsSections: [PodcastSection] = []
    var podcastsContinuationSections: [[PodcastSection]] = []
    var searchResponse: SearchResponse = .empty
    var searchContinuationResponses: [SearchResponse] = []
    var searchSuggestions: [SearchSuggestion] = []
    var libraryPlaylists: [Playlist] = []
    var likedTracks: [Track] = []
    var likedTracksContinuationTracks: [[Track]] = []
    var playlistDetails: [String: PlaylistDetail] = [:]
    var playlistContinuationTracks: [String: [[Track]]] = [:]
    var artistDetails: [String: ArtistDetail] = [:]
    var artistTracks: [String: [Track]] = [:]
    var artistTracksResponse: [Track] = []
    var moodCategoryResponse: HomeResponse = .init(sections: [])
    var lyricsResponses: [String: Lyrics] = [:]
    var radioQueueTracks: [String: [Track]] = [:]
    var trackMetadataByVideoId: [String: Track] = [:]
    var mixQueueResult: RadioQueueResult = .init(tracks: [], continuationToken: nil)
    var mixQueueContinuationResults: [String: RadioQueueResult] = [:]

    // MARK: - Continuation State

    private var _homeContinuationIndex = 0
    private var _exploreContinuationIndex = 0
    private var _chartsContinuationIndex = 0
    private var _moodsAndGenresContinuationIndex = 0
    private var _newReleasesContinuationIndex = 0
    private var _podcastsContinuationIndex = 0
    private var _likedTracksContinuationIndex = 0
    private var _playlistContinuationIndex = 0
    private var _currentPlaylistId: String?

    var hasMoreHomeSections: Bool {
        self._homeContinuationIndex < self.homeContinuationSections.count
    }

    var hasMoreExploreSections: Bool {
        self._exploreContinuationIndex < self.exploreContinuationSections.count
    }

    var hasMoreChartsSections: Bool {
        self._chartsContinuationIndex < self.chartsContinuationSections.count
    }

    var hasMoreMoodsAndGenresSections: Bool {
        self._moodsAndGenresContinuationIndex < self.moodsAndGenresContinuationSections.count
    }

    var hasMoreNewReleasesSections: Bool {
        self._newReleasesContinuationIndex < self.newReleasesContinuationSections.count
    }

    var hasMorePodcastsSections: Bool {
        self._podcastsContinuationIndex < self.podcastsContinuationSections.count
    }

    var hasMoreLikedTracks: Bool {
        self._likedTracksContinuationIndex < self.likedTracksContinuationTracks.count
    }

    var hasMorePlaylistTracks: Bool {
        guard let playlistId = _currentPlaylistId,
              let continuations = playlistContinuationTracks[playlistId]
        else { return false }
        return self._playlistContinuationIndex < continuations.count
    }

    private var _searchContinuationIndex = 0

    var hasMoreSearchResults: Bool {
        self._searchContinuationIndex < self.searchContinuationResponses.count
    }

    // MARK: - Call Tracking

    private(set) var getHomeCalled = false
    private(set) var getHomeCallCount = 0
    private(set) var getHomeContinuationCalled = false
    private(set) var getHomeContinuationCallCount = 0
    private(set) var getExploreCalled = false
    private(set) var getExploreCallCount = 0
    private(set) var getExploreContinuationCalled = false
    private(set) var getExploreContinuationCallCount = 0
    private(set) var searchCalled = false
    private(set) var searchQueries: [String] = []
    private(set) var getSearchSuggestionsCalled = false
    private(set) var getSearchSuggestionsQueries: [String] = []
    private(set) var getLibraryPlaylistsCalled = false
    private(set) var getLikedTracksCalled = false
    private(set) var getLikedTracksContinuationCalled = false
    private(set) var getLikedTracksContinuationCallCount = 0
    private(set) var getPlaylistCalled = false
    private(set) var getPlaylistIds: [String] = []
    private(set) var getPlaylistContinuationCalled = false
    private(set) var getPlaylistContinuationCallCount = 0
    private(set) var getArtistCalled = false
    private(set) var getArtistIds: [String] = []
    private(set) var getArtistTracksCalled = false
    private(set) var getArtistTracksBrowseIds: [String] = []
    private(set) var rateTrackCalled = false
    private(set) var rateTrackVideoIds: [String] = []
    private(set) var rateTrackRatings: [LikeStatus] = []
    private(set) var editTrackLibraryStatusCalled = false
    private(set) var editTrackLibraryStatusTokens: [[String]] = []
    private(set) var subscribeToPlaylistCalled = false
    private(set) var subscribeToPlaylistIds: [String] = []
    private(set) var unsubscribeFromPlaylistCalled = false
    private(set) var unsubscribeFromPlaylistIds: [String] = []
    private(set) var subscribeToArtistCalled = false
    private(set) var subscribeToArtistIds: [String] = []
    private(set) var unsubscribeFromArtistCalled = false
    private(set) var unsubscribeFromArtistIds: [String] = []
    private(set) var getLyricsCalled = false
    private(set) var getLyricsVideoIds: [String] = []
    private(set) var getRadioQueueCalled = false
    private(set) var getRadioQueueVideoIds: [String] = []
    private(set) var getMixQueueCalled = false
    private(set) var getMixQueuePlaylistIds: [String] = []
    private(set) var getMixQueueStartVideoIds: [String?] = []
    private(set) var getMixQueueContinuationCalled = false
    private(set) var getMixQueueContinuationTokens: [String] = []
    private(set) var moodCategoryCalled = false
    private(set) var switchAccountCalled = false
    private(set) var switchAccountBrandIds: [String?] = []

    // MARK: - Error Simulation

    var shouldThrowError: Error?

    // MARK: - Protocol Implementation

    func getHome(forceRefresh: Bool) async throws -> HomeResponse {
        self.getHomeCalled = true
        self.getHomeCallCount += 1
        self._homeContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.homeResponse
    }

    func getHomeContinuation() async throws -> [HomeSection]? {
        self.getHomeContinuationCalled = true
        self.getHomeContinuationCallCount += 1
        if let error = shouldThrowError { throw error }
        guard self._homeContinuationIndex < self.homeContinuationSections.count else {
            return nil
        }
        let sections = self.homeContinuationSections[self._homeContinuationIndex]
        self._homeContinuationIndex += 1
        return sections
    }

    func getExplore() async throws -> HomeResponse {
        self.getExploreCalled = true
        self.getExploreCallCount += 1
        self._exploreContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.exploreResponse
    }

    func getExploreContinuation() async throws -> [HomeSection]? {
        self.getExploreContinuationCalled = true
        self.getExploreContinuationCallCount += 1
        if let error = shouldThrowError { throw error }
        guard self._exploreContinuationIndex < self.exploreContinuationSections.count else {
            return nil
        }
        let sections = self.exploreContinuationSections[self._exploreContinuationIndex]
        self._exploreContinuationIndex += 1
        return sections
    }

    func getCharts() async throws -> HomeResponse {
        self._chartsContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.chartsResponse
    }

    func getChartsContinuation() async throws -> [HomeSection]? {
        if let error = shouldThrowError { throw error }
        guard self._chartsContinuationIndex < self.chartsContinuationSections.count else {
            return nil
        }
        let sections = self.chartsContinuationSections[self._chartsContinuationIndex]
        self._chartsContinuationIndex += 1
        return sections
    }

    func getMoodsAndGenres() async throws -> HomeResponse {
        self._moodsAndGenresContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.moodsAndGenresResponse
    }

    func getMoodsAndGenresContinuation() async throws -> [HomeSection]? {
        if let error = shouldThrowError { throw error }
        guard self._moodsAndGenresContinuationIndex < self.moodsAndGenresContinuationSections.count else {
            return nil
        }
        let sections = self.moodsAndGenresContinuationSections[self._moodsAndGenresContinuationIndex]
        self._moodsAndGenresContinuationIndex += 1
        return sections
    }

    func getNewReleases() async throws -> HomeResponse {
        self._newReleasesContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.newReleasesResponse
    }

    func getNewReleasesContinuation() async throws -> [HomeSection]? {
        if let error = shouldThrowError { throw error }
        guard self._newReleasesContinuationIndex < self.newReleasesContinuationSections.count else {
            return nil
        }
        let sections = self.newReleasesContinuationSections[self._newReleasesContinuationIndex]
        self._newReleasesContinuationIndex += 1
        return sections
    }

    func getPodcasts() async throws -> [PodcastSection] {
        self._podcastsContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.podcastsSections
    }

    func getPodcastsContinuation() async throws -> [PodcastSection]? {
        if let error = shouldThrowError { throw error }
        guard self._podcastsContinuationIndex < self.podcastsContinuationSections.count else {
            return nil
        }
        let sections = self.podcastsContinuationSections[self._podcastsContinuationIndex]
        self._podcastsContinuationIndex += 1
        return sections
    }

    func getPodcastShow(browseId _: String) async throws -> PodcastShowDetail {
        if let error = shouldThrowError { throw error }
        return PodcastShowDetail(
            show: PodcastShow(id: "test", title: "Test Show", author: nil, description: nil, thumbnailURL: nil, episodeCount: nil),
            episodes: [],
            continuationToken: nil,
            isSubscribed: false
        )
    }

    func getPodcastEpisodesContinuation(token _: String) async throws -> PodcastEpisodesContinuation {
        if let error = shouldThrowError { throw error }
        return PodcastEpisodesContinuation(episodes: [], continuationToken: nil)
    }

    func search(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        return self.searchResponse
    }

    func searchTracks(query: String) async throws -> [Track] {
        self.searchCalled = true
        self.searchQueries.append(query)
        if let error = shouldThrowError { throw error }
        return self.searchResponse.tracks
    }

    func searchTracksWithPagination(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: self.searchResponse.tracks,
            albums: [],
            artists: [],
            playlists: [],
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchVideosWithPagination(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            videos: self.searchResponse.videos,
            albums: [],
            artists: [],
            playlists: [],
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchAlbums(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            albums: self.searchResponse.albums,
            artists: [],
            playlists: [],
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchArtists(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            albums: [],
            artists: self.searchResponse.artists,
            playlists: [],
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchPlaylists(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            albums: [],
            artists: [],
            playlists: self.searchResponse.playlists,
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchFeaturedPlaylists(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            albums: [],
            artists: [],
            playlists: self.searchResponse.playlists,
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchCommunityPlaylists(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            albums: [],
            artists: [],
            playlists: self.searchResponse.playlists,
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func searchPodcasts(query: String) async throws -> SearchResponse {
        self.searchCalled = true
        self.searchQueries.append(query)
        self._searchContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.searchContinuationResponses.isEmpty
        return SearchResponse(
            tracks: [],
            albums: [],
            artists: [],
            playlists: [],
            podcastShows: [],
            continuationToken: hasMore ? "mock-token" : nil
        )
    }

    func getSearchContinuation() async throws -> SearchResponse? {
        if let error = shouldThrowError { throw error }
        guard self._searchContinuationIndex < self.searchContinuationResponses.count else {
            return nil
        }
        let response = self.searchContinuationResponses[self._searchContinuationIndex]
        self._searchContinuationIndex += 1
        return response
    }

    func clearSearchContinuation() {
        self._searchContinuationIndex = 0
    }

    func resetSessionStateForAccountSwitch() {
        self._homeContinuationIndex = 0
        self._exploreContinuationIndex = 0
        self._chartsContinuationIndex = 0
        self._moodsAndGenresContinuationIndex = 0
        self._newReleasesContinuationIndex = 0
        self._podcastsContinuationIndex = 0
        self._likedTracksContinuationIndex = 0
        self._playlistContinuationIndex = 0
        self._searchContinuationIndex = 0
        self._currentPlaylistId = nil
    }

    func getSearchSuggestions(query: String) async throws -> [SearchSuggestion] {
        self.getSearchSuggestionsCalled = true
        self.getSearchSuggestionsQueries.append(query)
        if let error = shouldThrowError { throw error }
        return self.searchSuggestions
    }

    func getLibraryPlaylists() async throws -> [Playlist] {
        self.getLibraryPlaylistsCalled = true
        if let error = shouldThrowError { throw error }
        return self.libraryPlaylists
    }

    func getLibraryContent() async throws -> PlaylistParser.LibraryContent {
        self.getLibraryPlaylistsCalled = true
        if let error = shouldThrowError { throw error }
        return PlaylistParser.LibraryContent(playlists: self.libraryPlaylists, podcastShows: [])
    }

    func getLikedTracks() async throws -> LikedTracksResponse {
        self.getLikedTracksCalled = true
        self._likedTracksContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        let hasMore = !self.likedTracksContinuationTracks.isEmpty
        return LikedTracksResponse(tracks: self.likedTracks, continuationToken: hasMore ? "mock-token" : nil)
    }

    func getLikedTracksContinuation() async throws -> LikedTracksResponse? {
        self.getLikedTracksContinuationCalled = true
        self.getLikedTracksContinuationCallCount += 1
        if let error = shouldThrowError { throw error }
        guard self._likedTracksContinuationIndex < self.likedTracksContinuationTracks.count else {
            return nil
        }
        let tracks = self.likedTracksContinuationTracks[self._likedTracksContinuationIndex]
        self._likedTracksContinuationIndex += 1
        let hasMore = self._likedTracksContinuationIndex < self.likedTracksContinuationTracks.count
        return LikedTracksResponse(tracks: tracks, continuationToken: hasMore ? "mock-token-\(self._likedTracksContinuationIndex)" : nil)
    }

    func getPlaylist(id: String) async throws -> PlaylistTracksResponse {
        self.getPlaylistCalled = true
        self.getPlaylistIds.append(id)
        self._currentPlaylistId = id
        self._playlistContinuationIndex = 0
        if let error = shouldThrowError { throw error }
        guard let detail = playlistDetails[id] else {
            throw YTMusicError.parseError(message: "Playlist not found: \(id)")
        }
        let hasContinuation = self.playlistContinuationTracks[id]?.isEmpty == false
        return PlaylistTracksResponse(detail: detail, continuationToken: hasContinuation ? "mock-token" : nil)
    }

    func getPlaylistContinuation() async throws -> PlaylistContinuationResponse? {
        self.getPlaylistContinuationCalled = true
        self.getPlaylistContinuationCallCount += 1
        if let error = shouldThrowError { throw error }
        guard let playlistId = _currentPlaylistId,
              let continuations = playlistContinuationTracks[playlistId],
              self._playlistContinuationIndex < continuations.count
        else {
            return nil
        }
        let tracks = continuations[self._playlistContinuationIndex]
        self._playlistContinuationIndex += 1
        let hasMore = self._playlistContinuationIndex < continuations.count
        return PlaylistContinuationResponse(tracks: tracks, continuationToken: hasMore ? "mock-token-\(self._playlistContinuationIndex)" : nil)
    }

    func getPlaylistAllTracks(playlistId: String) async throws -> [Track] {
        if let error = shouldThrowError { throw error }
        guard let detail = playlistDetails[playlistId] else {
            throw YTMusicError.parseError(message: "Playlist not found: \(playlistId)")
        }
        var allTracks = detail.tracks
        if let continuations = playlistContinuationTracks[playlistId] {
            for batch in continuations {
                allTracks.append(contentsOf: batch)
            }
        }
        return allTracks
    }

    func getArtist(id: String) async throws -> ArtistDetail {
        self.getArtistCalled = true
        self.getArtistIds.append(id)
        if let error = shouldThrowError { throw error }
        guard let detail = artistDetails[id] else {
            throw YTMusicError.parseError(message: "Artist not found: \(id)")
        }
        return detail
    }

    func getArtistTracks(browseId: String, params _: String?) async throws -> [Track] {
        self.getArtistTracksCalled = true
        self.getArtistTracksBrowseIds.append(browseId)
        if let error = shouldThrowError { throw error }
        // Return artistTracksResponse if set, otherwise fall back to dictionary lookup
        if !self.artistTracksResponse.isEmpty {
            return self.artistTracksResponse
        }
        return self.artistTracks[browseId] ?? []
    }

    func rateTrack(videoId: String, rating: LikeStatus) async throws {
        self.rateTrackCalled = true
        self.rateTrackVideoIds.append(videoId)
        self.rateTrackRatings.append(rating)
        if let error = shouldThrowError { throw error }
    }

    func editTrackLibraryStatus(feedbackTokens: [String]) async throws {
        self.editTrackLibraryStatusCalled = true
        self.editTrackLibraryStatusTokens.append(feedbackTokens)
        if let error = shouldThrowError { throw error }
    }

    func subscribeToPlaylist(playlistId: String) async throws {
        self.subscribeToPlaylistCalled = true
        self.subscribeToPlaylistIds.append(playlistId)
        if let error = shouldThrowError { throw error }
    }

    func unsubscribeFromPlaylist(playlistId: String) async throws {
        self.unsubscribeFromPlaylistCalled = true
        self.unsubscribeFromPlaylistIds.append(playlistId)
        if let error = shouldThrowError { throw error }
    }

    func subscribeToPodcast(showId: String) async throws {
        if let error = shouldThrowError { throw error }
        // Validate podcast show ID format (mirrors real YTMusicClient behavior)
        if showId.hasPrefix("MPSPP") {
            let suffix = String(showId.dropFirst(5))
            if suffix.isEmpty {
                throw YTMusicError.invalidInput("Invalid podcast show ID: \(showId)")
            }
            if !suffix.hasPrefix("L") {
                throw YTMusicError.invalidInput("Invalid podcast show ID format: \(showId)")
            }
        }
    }

    func unsubscribeFromPodcast(showId: String) async throws {
        if let error = shouldThrowError { throw error }
        // Validate podcast show ID format (mirrors real YTMusicClient behavior)
        if showId.hasPrefix("MPSPP") {
            let suffix = String(showId.dropFirst(5))
            if suffix.isEmpty {
                throw YTMusicError.invalidInput("Invalid podcast show ID: \(showId)")
            }
            if !suffix.hasPrefix("L") {
                throw YTMusicError.invalidInput("Invalid podcast show ID format: \(showId)")
            }
        }
    }

    func subscribeToArtist(channelId: String) async throws {
        self.subscribeToArtistCalled = true
        self.subscribeToArtistIds.append(channelId)
        if let error = shouldThrowError { throw error }
    }

    func unsubscribeFromArtist(channelId: String) async throws {
        self.unsubscribeFromArtistCalled = true
        self.unsubscribeFromArtistIds.append(channelId)
        if let error = shouldThrowError { throw error }
    }

    func getLyrics(videoId: String) async throws -> Lyrics {
        self.getLyricsCalled = true
        self.getLyricsVideoIds.append(videoId)
        if let error = shouldThrowError { throw error }
        return self.lyricsResponses[videoId] ?? .unavailable
    }

    func getTrack(videoId: String) async throws -> Track {
        if let error = shouldThrowError { throw error }
        if let track = self.trackMetadataByVideoId[videoId] {
            return track
        }
        return Track(
            id: videoId,
            title: "Mock Track",
            artists: [Artist(id: "mock-artist", name: "Mock Artist")],
            videoId: videoId
        )
    }

    func getRadioQueue(videoId: String) async throws -> [Track] {
        self.getRadioQueueCalled = true
        self.getRadioQueueVideoIds.append(videoId)
        if let error = shouldThrowError { throw error }
        return self.radioQueueTracks[videoId] ?? []
    }

    func getMixQueue(playlistId: String, startVideoId: String?) async throws -> RadioQueueResult {
        self.getMixQueueCalled = true
        self.getMixQueuePlaylistIds.append(playlistId)
        self.getMixQueueStartVideoIds.append(startVideoId)
        if let error = shouldThrowError { throw error }
        return self.mixQueueResult
    }

    func getMixQueueContinuation(continuationToken: String) async throws -> RadioQueueResult {
        self.getMixQueueContinuationCalled = true
        self.getMixQueueContinuationTokens.append(continuationToken)
        if let error = shouldThrowError { throw error }
        return self.mixQueueContinuationResults[continuationToken] ?? .init(tracks: [], continuationToken: nil)
    }

    func getMoodCategory(browseId _: String, params _: String?) async throws -> HomeResponse {
        self.moodCategoryCalled = true
        if let error = shouldThrowError { throw error }
        return self.moodCategoryResponse
    }

    func fetchAccountsList() async throws -> AccountsListResponse {
        if let error = shouldThrowError { throw error }
        return AccountsListResponse(googleEmail: "test@gmail.com", accounts: [])
    }

    func switchAccount(brandId: String?) async throws {
        self.switchAccountCalled = true
        self.switchAccountBrandIds.append(brandId)
        if let error = shouldThrowError { throw error }
        self.resetSessionStateForAccountSwitch()
    }

    // MARK: - Helper Methods

    /// Resets all call tracking.
    func reset() {
        self.getHomeCalled = false
        self.getHomeCallCount = 0
        self.getHomeContinuationCalled = false
        self.getHomeContinuationCallCount = 0
        self._homeContinuationIndex = 0
        self.getExploreCalled = false
        self.getExploreCallCount = 0
        self.getExploreContinuationCalled = false
        self.getExploreContinuationCallCount = 0
        self._exploreContinuationIndex = 0
        self._chartsContinuationIndex = 0
        self._moodsAndGenresContinuationIndex = 0
        self._newReleasesContinuationIndex = 0
        self._podcastsContinuationIndex = 0
        self._likedTracksContinuationIndex = 0
        self._playlistContinuationIndex = 0
        self._currentPlaylistId = nil
        self.searchCalled = false
        self.searchQueries = []
        self.getSearchSuggestionsCalled = false
        self.getSearchSuggestionsQueries = []
        self.getLibraryPlaylistsCalled = false
        self.getLikedTracksCalled = false
        self.getLikedTracksContinuationCalled = false
        self.getLikedTracksContinuationCallCount = 0
        self.getPlaylistCalled = false
        self.getPlaylistIds = []
        self.getPlaylistContinuationCalled = false
        self.getPlaylistContinuationCallCount = 0
        self.getArtistCalled = false
        self.getArtistIds = []
        self.getArtistTracksCalled = false
        self.getArtistTracksBrowseIds = []
        self.rateTrackCalled = false
        self.rateTrackVideoIds = []
        self.rateTrackRatings = []
        self.editTrackLibraryStatusCalled = false
        self.editTrackLibraryStatusTokens = []
        self.subscribeToPlaylistCalled = false
        self.subscribeToPlaylistIds = []
        self.unsubscribeFromPlaylistCalled = false
        self.unsubscribeFromPlaylistIds = []
        self.subscribeToArtistCalled = false
        self.subscribeToArtistIds = []
        self.unsubscribeFromArtistCalled = false
        self.unsubscribeFromArtistIds = []
        self.getLyricsCalled = false
        self.getLyricsVideoIds = []
        self.getRadioQueueCalled = false
        self.getRadioQueueVideoIds = []
        self.getMixQueueCalled = false
        self.getMixQueuePlaylistIds = []
        self.getMixQueueStartVideoIds = []
        self.getMixQueueContinuationCalled = false
        self.getMixQueueContinuationTokens = []
        self.moodCategoryCalled = false
        self.switchAccountCalled = false
        self.switchAccountBrandIds = []
        self.trackMetadataByVideoId = [:]
        self.shouldThrowError = nil
    }
}
