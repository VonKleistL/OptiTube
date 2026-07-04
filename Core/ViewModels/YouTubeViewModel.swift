import Foundation
import os

// MARK: - YouTubeViewModel

/// View model for the YouTube video mode experience.
///
/// Owns all feed loading, search, pagination state, and URL/ID detection.
/// `YouTubeContentView` binds to this class and never calls the API client directly.
@Observable
@MainActor
final class YouTubeViewModel {
    // MARK: - Published State

    private(set) var selection: YouTubeNavigationItem = .home
    var query: String = ""
    var activeSearchFilters = YouTubeSearchFilters()

    private(set) var sections: [YouTubeFeedSection] = []
    private(set) var searchResults: [YouTubeFeedItem] = []
    private(set) var loadingState: LoadingState = .idle
    private(set) var continuationToken: String?
    private(set) var isLoadingMore = false
    private(set) var isSearchMode = false

    // MARK: - Dependencies

    private let client: any YouTubeClientProtocol
    private let playerService: YouTubePlayerService

    // MARK: - Task Management

    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(client: any YouTubeClientProtocol, playerService: YouTubePlayerService) {
        self.client = client
        self.playerService = playerService
    }

    // MARK: - Public API

    func load(selection: YouTubeNavigationItem, forceRefresh: Bool = false) async {
        // If switching to search, just focus the bar — don't fetch a feed
        if selection == .search {
            self.selection = selection
            self.isSearchMode = true
            return
        }

        // Leaving search: wipe the stale query/results and refetch the feed
        // (the continuation token in play belongs to the search, not the feed).
        var forceRefresh = forceRefresh
        if self.isSearchMode {
            self.clearSearch()
            forceRefresh = true
        }

        // Avoid redundant fetches unless forced
        if self.selection == selection, !self.sections.isEmpty, !forceRefresh { return }

        self.selection = selection
        self.isSearchMode = false
        self.continuationToken = nil
        self.sections = []
        self.loadingState = .loading

        self.loadTask?.cancel()
        self.loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.fetchFeed(for: selection)
                guard !Task.isCancelled else { return }
                self.sections = response.sections
                self.continuationToken = response.continuationToken
                self.loadingState = .loaded
            } catch is CancellationError {
                // Silently ignore
            } catch YTMusicError.authExpired {
                guard !Task.isCancelled else { return }
                self.loadingState = .authRequired
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingState = .error(LoadingError(from: error))
                DiagnosticsLogger.api.error("YouTubeViewModel load failed: \(error)")
            }
        }
        await self.loadTask?.value
    }

    func submitSearchOrURL() {
        let input = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        if let videoId = Self.extractVideoId(from: input), !videoId.isEmpty {
            // Treat as direct play
            let video = YouTubeVideo(videoId: videoId, title: "Loading…")
            self.playerService.play(video: video)
        } else {
            // Run a search
            self.isSearchMode = true
            self.searchTask?.cancel()
            self.searchTask = Task { [weak self] in
                await self?.search()
            }
        }
    }

    func search() async {
        let q = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        self.isSearchMode = true
        self.searchResults = []
        self.continuationToken = nil
        self.loadingState = .loading

        do {
            let response = try await self.client.search(query: q, filters: self.activeSearchFilters)
            guard !Task.isCancelled else { return }
            self.searchResults = response.allItems
            self.continuationToken = response.continuationToken
            self.loadingState = .loaded
        } catch is CancellationError {
            // Silently ignore
        } catch YTMusicError.authExpired {
            self.loadingState = .authRequired
        } catch {
            guard !Task.isCancelled else { return }
            self.loadingState = .error(LoadingError(from: error))
            DiagnosticsLogger.api.error("YouTubeViewModel search failed: \(error)")
        }
    }

    func loadMore() async {
        guard let token = self.continuationToken, !self.isLoadingMore else { return }

        self.isLoadingMore = true
        defer { self.isLoadingMore = false }

        do {
            let wasSearchMode = self.isSearchMode
            let response = if wasSearchMode {
                try await self.client.searchContinuation(token)
            } else {
                try await self.client.getContinuation(token)
            }
            guard !Task.isCancelled,
                  self.continuationToken == token,
                  self.isSearchMode == wasSearchMode
            else { return }

            if wasSearchMode {
                self.searchResults.append(contentsOf: response.allItems)
            } else {
                // Merge new sections into existing sections
                for newSection in response.sections {
                    if let idx = self.sections.firstIndex(where: {
                        ($0.title == newSection.title) || ($0.title == nil && newSection.title == nil)
                    }) {
                        let merged = YouTubeFeedSection(
                            id: self.sections[idx].id,
                            title: self.sections[idx].title,
                            items: self.sections[idx].items + newSection.items
                        )
                        self.sections[idx] = merged
                    } else {
                        self.sections.append(newSection)
                    }
                }
            }
            self.continuationToken = response.continuationToken
        } catch is CancellationError {
            return
        } catch {
            DiagnosticsLogger.api.error("YouTubeViewModel loadMore failed: \(error)")
        }
    }

    func clearSearch() {
        self.query = ""
        self.searchResults = []
        self.continuationToken = nil
        self.isSearchMode = false
        self.loadingState = self.sections.isEmpty ? .idle : .loaded
        self.searchTask?.cancel()
    }

    func play(_ video: YouTubeVideo) {
        self.playerService.play(video: video)
    }

    /// Replaces the feed with the contents of a single playlist.
    func openPlaylist(_ playlist: YouTubePlaylistItem) {
        self.replaceFeed(title: playlist.title, logLabel: "openPlaylist") { client in
            try await client.getPlaylistFeed(playlistId: playlist.playlistId)
        }
    }

    /// Replaces the feed with a channel's videos.
    func openChannel(_ channel: YouTubeChannelItem) {
        self.replaceFeed(title: channel.name, logLabel: "openChannel") { client in
            try await client.getChannelFeed(channelId: channel.channelId)
        }
    }

    /// Shared drill-in loader: swaps the feed for a fetched collection.
    private func replaceFeed(
        title: String,
        logLabel: String,
        fetch: @escaping @MainActor (any YouTubeClientProtocol) async throws -> YouTubeFeedResponse
    ) {
        self.isSearchMode = false
        self.sections = []
        self.continuationToken = nil
        self.loadingState = .loading

        self.loadTask?.cancel()
        self.loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                var response = try await fetch(self.client)
                guard !Task.isCancelled else { return }
                if response.sections.count == 1, response.sections[0].title == nil {
                    // Give the single unnamed section the collection's title.
                    let section = response.sections[0]
                    response = YouTubeFeedResponse(
                        sections: [YouTubeFeedSection(id: section.id, title: title, items: section.items)],
                        continuationToken: response.continuationToken
                    )
                }
                self.sections = response.sections
                self.continuationToken = response.continuationToken
                self.loadingState = .loaded
            } catch is CancellationError {
                // Silently ignore
            } catch YTMusicError.authExpired {
                guard !Task.isCancelled else { return }
                self.loadingState = .authRequired
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingState = .error(LoadingError(from: error))
                DiagnosticsLogger.api.error("YouTubeViewModel \(logLabel) failed: \(error)")
            }
        }
    }

    func refresh() async {
        await self.load(selection: self.selection, forceRefresh: true)
    }

    // MARK: - Private Helpers

    private func fetchFeed(for selection: YouTubeNavigationItem) async throws -> YouTubeFeedResponse {
        switch selection {
        case .home: return try await self.client.getHomeFeed()
        case .subscriptions: return try await self.client.getSubscriptionsFeed()
        case .explore: return try await self.client.getExploreFeed()
        case .history: return try await self.client.getHistoryFeed()
        case .likedVideos: return try await self.client.getLikedVideos()
        case .watchLater: return try await self.client.getWatchLater()
        case .playlists: return try await self.client.getPlaylists()
        case .search:
            // Search handled separately
            return YouTubeFeedResponse(sections: [], continuationToken: nil)
        }
    }

    /// Extracts a YouTube video ID from a raw URL or ID string.
    static func extractVideoId(from input: String) -> String? {
        // Standard watch URL: https://www.youtube.com/watch?v=VIDEO_ID
        if input.contains("v="),
           let id = input.components(separatedBy: "v=").last?
           .components(separatedBy: "&").first,
           id.count == 11
        {
            return id
        }
        // Short URL: https://youtu.be/VIDEO_ID
        if input.contains("youtu.be/"),
           let id = input.components(separatedBy: "youtu.be/").last?
           .components(separatedBy: "?").first,
           id.count == 11
        {
            return id
        }
        // Shorts URL: https://www.youtube.com/shorts/VIDEO_ID
        if input.contains("/shorts/"),
           let id = input.components(separatedBy: "/shorts/").last?
           .components(separatedBy: "?").first,
           id.count == 11
        {
            return id
        }
        // Raw 11-char video ID (YouTube IDs are always exactly 11 characters)
        if input.count == 11,
           input.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        {
            return input
        }
        return nil
    }
}
