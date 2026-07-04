import Foundation

// MARK: - YouTubeClientProtocol

/// Protocol for the regular YouTube (non-Music) API client.
/// All feed and search operations use the signed-in YouTube session.
@MainActor
protocol YouTubeClientProtocol: AnyObject {
    // MARK: Feeds

    func getHomeFeed() async throws -> YouTubeFeedResponse
    func getSubscriptionsFeed() async throws -> YouTubeFeedResponse
    func getExploreFeed() async throws -> YouTubeFeedResponse
    func getHistoryFeed() async throws -> YouTubeFeedResponse
    func getLikedVideos() async throws -> YouTubeFeedResponse
    func getWatchLater() async throws -> YouTubeFeedResponse
    func getPlaylists() async throws -> YouTubeFeedResponse

    /// Fetches the videos of a single playlist.
    func getPlaylistFeed(playlistId: String) async throws -> YouTubeFeedResponse

    /// Fetches a channel's videos.
    func getChannelFeed(channelId: String) async throws -> YouTubeFeedResponse

    /// Fetches the next page using a continuation token returned by any feed or search.
    func getContinuation(_ token: String) async throws -> YouTubeFeedResponse

    // MARK: Search

    func search(
        query: String,
        filters: YouTubeSearchFilters
    ) async throws -> YouTubeFeedResponse

    func searchContinuation(_ token: String) async throws -> YouTubeFeedResponse
}
