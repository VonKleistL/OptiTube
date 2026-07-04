import Foundation

// MARK: - YouTubeFeedItem

/// A single item that can appear in a YouTube feed or search result.
enum YouTubeFeedItem: Identifiable, Hashable, Sendable {
    case video(YouTubeVideo)
    case playlist(YouTubePlaylistItem)
    case channel(YouTubeChannelItem)

    var id: String {
        switch self {
        case let .video(v): "v:\(v.videoId)"
        case let .playlist(p): "p:\(p.playlistId)"
        case let .channel(c): "c:\(c.channelId)"
        }
    }

    /// The video, if this item is a video.
    var video: YouTubeVideo? {
        if case let .video(v) = self { return v }
        return nil
    }
}

// MARK: - YouTubePlaylistItem

struct YouTubePlaylistItem: Identifiable, Hashable, Sendable {
    let playlistId: String
    let title: String
    let channelName: String?
    let thumbnailURL: URL?
    let videoCount: String?

    var id: String { self.playlistId }
}

// MARK: - YouTubeChannelItem

struct YouTubeChannelItem: Identifiable, Hashable, Sendable {
    let channelId: String
    let name: String
    let thumbnailURL: URL?
    let subscriberCountText: String?
    let videoCountText: String?

    var id: String { self.channelId }
}

// MARK: - YouTubeFeedSection

/// A titled section of feed items (e.g. "Trending", "Subscriptions").
struct YouTubeFeedSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let items: [YouTubeFeedItem]

    init(id: String = UUID().uuidString, title: String?, items: [YouTubeFeedItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

// MARK: - YouTubeFeedResponse

/// Top-level response from a YouTube feed or search endpoint.
struct YouTubeFeedResponse: Sendable {
    let sections: [YouTubeFeedSection]
    /// Continuation token for fetching the next page.
    let continuationToken: String?

    /// All feed items flattened across all sections.
    var allItems: [YouTubeFeedItem] {
        self.sections.flatMap(\.items)
    }

    var isEmpty: Bool {
        self.sections.allSatisfy { $0.items.isEmpty }
    }
}
