import CryptoKit
import Foundation
import os

// MARK: - YouTubeClient

/// Authenticated client for the regular YouTube (non-Music) InnerTube API.
///
/// Uses a `WEB` client context with `www.youtube.com` as the origin,
/// distinct from `YTMusicClient` which uses `WEB_REMIX` and `music.youtube.com`.
/// Cookies are shared (same Google account / WebKit data store) but SAPISIDHASH
/// must be computed with the correct origin for each API surface.
@MainActor
final class YouTubeClient: YouTubeClientProtocol {
    private let webKitManager: WebKitManager
    private let session: URLSession
    private let logger = DiagnosticsLogger.api

    var brandIdProvider: (() -> String?)?

    // MARK: - API Constants

    /// Regular YouTube InnerTube base URL.
    private static let baseURL = "https://www.youtube.com/youtubei/v1"

    /// Regular YouTube origin for SAPISIDHASH and request headers.
    private static let origin = "https://www.youtube.com"

    // MARK: - Browse IDs

    private enum BrowseID {
        static let home = "FEwhat_to_watch"
        static let subscriptions = "FEsubscriptions"
        static let shorts = "FEshorts"
        static let history = "FEhistory"
        static let watchLater = "VLWL"
        static let likedVideos = "VLLL"
        static let playlists = "FEplaylist_aggregation"
    }

    // MARK: - Init

    init(webKitManager: WebKitManager = .shared) {
        self.webKitManager = webKitManager

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept-Encoding": "gzip, deflate, br",
        ]
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        self.session = URLSession(configuration: config)
    }

    // MARK: - Feeds

    func getHomeFeed() async throws -> YouTubeFeedResponse {
        let json = try await self.browse(browseId: BrowseID.home)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getSubscriptionsFeed() async throws -> YouTubeFeedResponse {
        let json = try await self.browse(browseId: BrowseID.subscriptions)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getExploreFeed() async throws -> YouTubeFeedResponse {
        let json = try await YouTubeWebContextService.shared.loadInitialData(for: "/feed/explore")
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getHistoryFeed() async throws -> YouTubeFeedResponse {
        let json = try await self.browse(browseId: BrowseID.history)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getLikedVideos() async throws -> YouTubeFeedResponse {
        let json = try await self.browse(browseId: BrowseID.likedVideos)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getWatchLater() async throws -> YouTubeFeedResponse {
        let json = try await self.browse(browseId: BrowseID.watchLater)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getPlaylists() async throws -> YouTubeFeedResponse {
        let json = try await self.browse(browseId: BrowseID.playlists)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getPlaylistFeed(playlistId: String) async throws -> YouTubeFeedResponse {
        let browseId = playlistId.hasPrefix("VL") ? playlistId : "VL\(playlistId)"
        let json = try await self.browse(browseId: browseId)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getChannelFeed(channelId: String) async throws -> YouTubeFeedResponse {
        // params selects the channel's Videos tab so a parseable grid comes back.
        let json = try await self.browse(browseId: channelId, params: "EgZ2aWRlb3PyBgQKAjoA")
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    func getContinuation(_ token: String) async throws -> YouTubeFeedResponse {
        let decodedToken = token.removingPercentEncoding ?? token
        let body: [String: Any] = ["continuation": decodedToken]
        let json = try await self.request("browse", body: body)
        return YouTubeResponseParser.parseFeedResponse(json)
    }

    // MARK: - Search

    func search(query: String, filters: YouTubeSearchFilters) async throws -> YouTubeFeedResponse {
        var body: [String: Any] = ["query": query]
        if let param = filters.resolvedParam {
            body["params"] = param
        }
        let json = try await self.request("search", body: body)
        return YouTubeResponseParser.parseSearchResponse(json)
    }

    func searchContinuation(_ token: String) async throws -> YouTubeFeedResponse {
        let decodedToken = token.removingPercentEncoding ?? token
        let body: [String: Any] = ["continuation": decodedToken]
        let json = try await self.request("search", body: body)
        return YouTubeResponseParser.parseSearchResponse(json)
    }

    // MARK: - Private Networking

    private func browse(browseId: String, params: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["browseId": browseId]
        if let params {
            body["params"] = params
        }
        return try await self.request("browse", body: body)
    }

    private func request(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        try await self.performRequest(endpoint, body: body, retryOn400: true)
    }

    private func performRequest(_ endpoint: String, body: [String: Any], retryOn400: Bool) async throws -> [String: Any] {
        let context = try await YouTubeWebContextService.shared.fetchContext()

        var fullBody = body
        fullBody["context"] = self.buildContext(context)

        let urlString = "\(Self.baseURL)/\(endpoint)?key=\(context.apiKey)&prettyPrint=false"
        guard let url = URL(string: urlString) else {
            throw YTMusicError.unknown(message: "Invalid URL: \(urlString)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let headers = try await self.buildAuthHeaders()
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: fullBody)

        self.logger.debug("YouTubeClient → \(endpoint)")

        let (data, response) = try await self.session.data(for: req)

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 400:
                if retryOn400 {
                    self.logger.warning("YouTubeClient: HTTP 400, invalidating context and retrying...")
                    YouTubeWebContextService.shared.invalidateContext()
                    return try await self.performRequest(endpoint, body: body, retryOn400: false)
                }
                throw YTMusicError.unknown(message: "HTTP 400 for \(endpoint)")
            case 401, 403:
                throw YTMusicError.authExpired
            default:
                throw YTMusicError.unknown(message: "HTTP \(http.statusCode) for \(endpoint)")
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YTMusicError.unknown(message: "Invalid JSON from \(endpoint)")
        }

        return json
    }

    // MARK: - Auth

    private func buildAuthHeaders() async throws -> [String: String] {
        guard let cookieHeader = await self.webKitManager.cookieHeader(for: "youtube.com") else {
            self.logger.warning("YouTubeClient: no cookies for youtube.com — requests will be unauthenticated")
            // Return minimal headers so unauthenticated requests (e.g. trending) still work
            return [
                "Content-Type": "application/json",
                "Origin": Self.origin,
                "Referer": Self.origin,
            ]
        }

        // SAPISIDHASH uses www.youtube.com origin (not music.youtube.com)
        guard let sapisid = await self.webKitManager.getSAPISID() else {
            self.logger.warning("YouTubeClient: SAPISID missing — requests may be unauthenticated")
            return [
                "Cookie": cookieHeader,
                "Content-Type": "application/json",
                "Origin": Self.origin,
                "Referer": Self.origin,
            ]
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let hashInput = "\(timestamp) \(sapisid) \(Self.origin)"
        let hash = Insecure.SHA1.hash(data: Data(hashInput.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let sapisidhash = "\(timestamp)_\(hash)"

        var headers = [
            "Cookie": cookieHeader,
            "Authorization": "SAPISIDHASH \(sapisidhash)",
            "Origin": Self.origin,
            "Referer": Self.origin,
            "Content-Type": "application/json",
            "X-Goog-AuthUser": "0",
            "X-Origin": Self.origin,
        ]

        if let context = try? await YouTubeWebContextService.shared.fetchContext(), let visitorData = context.visitorData {
            headers["X-Goog-Visitor-Id"] = visitorData
        }

        return headers
    }

    private func buildContext(_ webContext: YouTubeWebContextService.YouTubeContext) -> [String: Any] {
        var client: [String: Any] = [
            "clientName": webContext.clientName,
            "clientVersion": webContext.clientVersion,
            "hl": "en",
            "gl": "US",
            "browserName": "Safari",
            "browserVersion": "17.0",
            "osName": "Macintosh",
            "osVersion": "10_15_7",
            "platform": "DESKTOP",
            "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "utcOffsetMinutes": -TimeZone.current.secondsFromGMT() / 60,
        ]

        if let visitorData = webContext.visitorData {
            client["visitorData"] = visitorData
        }

        var userDict: [String: Any] = [
            "lockedSafetyMode": false,
        ]
        if let brandId = self.brandIdProvider?() {
            userDict["onBehalfOfUser"] = brandId
        }

        return [
            "client": client,
            "user": userDict,
        ]
    }
}
