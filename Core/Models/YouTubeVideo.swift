// YouTubeVideo.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation

/// A regular YouTube video as it appears in feeds, search results, and related lists.
struct YouTubeVideo: Identifiable, Hashable, Sendable {
    let videoId: String
    let title: String
    let channelName: String?
    let channelId: String?
    /// Display duration, e.g. "28:01". `nil` for live streams.
    let lengthText: String?
    /// Short display view count, e.g. "29K views".
    let viewCountText: String?
    /// Relative publish date, e.g. "1 year ago".
    let publishedText: String?
    let thumbnailURL: URL?
    let isLive: Bool
    /// Whether this is a YouTube Short (vertical, ≤60s).
    let isShort: Bool
    /// Percent of the video the signed-in user has already watched (0–100).
    let watchedPercent: Int?

    var id: String {
        self.videoId
    }

    init(
        videoId: String,
        title: String,
        channelName: String? = nil,
        channelId: String? = nil,
        lengthText: String? = nil,
        viewCountText: String? = nil,
        publishedText: String? = nil,
        thumbnailURL: URL? = nil,
        isLive: Bool = false,
        isShort: Bool = false,
        watchedPercent: Int? = nil
    ) {
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.channelId = channelId
        self.lengthText = lengthText
        self.viewCountText = viewCountText
        self.publishedText = publishedText
        self.thumbnailURL = thumbnailURL
        self.isLive = isLive
        self.isShort = isShort
        self.watchedPercent = watchedPercent
    }
}

/// A caption track offered by the watch page player.
struct YouTubeCaptionTrack: Identifiable, Hashable, Sendable {
    let languageCode: String
    let displayName: String

    var id: String {
        self.languageCode
    }
}

/// Display helpers for YouTube's quality-level identifiers.
enum YouTubeQuality {
    /// Human-readable name for a player quality level (e.g. "hd1080" → "1080p").
    static func displayName(for level: String) -> String {
        switch level {
        case "highres": "4320p (8K)"
        case "hd2880": "2880p"
        case "hd2160": "2160p (4K)"
        case "hd1440": "1440p"
        case "hd1080": "1080p"
        case "hd720": "720p"
        case "large": "480p"
        case "medium": "360p"
        case "small": "240p"
        case "tiny": "144p"
        case "auto": String(localized: "Auto")
        default: level
        }
    }
}

/// Rating actions for a video.
enum YouTubeRating: Sendable {
    case like
    case dislike
    case none

    /// InnerTube action endpoint for this rating.
    var endpoint: String {
        switch self {
        case .like: "like/like"
        case .dislike: "like/dislike"
        case .none: "like/removelike"
        }
    }
}
