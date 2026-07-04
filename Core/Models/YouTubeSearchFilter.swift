import Foundation

// MARK: - YouTubeSearchTypeFilter

enum YouTubeSearchTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case video = "Videos"
    case channel = "Channels"
    case playlist = "Playlists"

    var id: String { self.rawValue }

    /// Base64-encoded protobuf param for YouTube InnerTube search API.
    /// `nil` means no filter param (use default).
    var searchParam: String? {
        switch self {
        case .all: nil
        case .video: "EgIQAQ=="
        case .channel: "EgIQAg=="
        case .playlist: "EgIQAw=="
        }
    }
}

// MARK: - YouTubeSearchUploadDateFilter

enum YouTubeSearchUploadDateFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any time"
    case lastHour = "Last hour"
    case today = "Today"
    case thisWeek = "This week"
    case thisMonth = "This month"
    case thisYear = "This year"

    var id: String { self.rawValue }

    var searchParam: String? {
        switch self {
        case .any: nil
        case .lastHour: "EgQIARAB"
        case .today: "EgQIAhAB"
        case .thisWeek: "EgQIAxAB"
        case .thisMonth: "EgQIBBAB"
        case .thisYear: "EgQIBRAB"
        }
    }
}

// MARK: - YouTubeSearchDurationFilter

enum YouTubeSearchDurationFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any duration"
    case short = "Under 4 min"
    case medium = "4–20 min"
    case long = "Over 20 min"

    var id: String { self.rawValue }

    var searchParam: String? {
        switch self {
        case .any: nil
        case .short: "EgQQARgB"
        case .medium: "EgQQARgD"
        case .long: "EgQQARgC"
        }
    }
}

// MARK: - YouTubeSearchSortFilter

enum YouTubeSearchSortFilter: String, CaseIterable, Identifiable, Sendable {
    case relevance = "Relevance"
    case uploadDate = "Upload date"
    case viewCount = "View count"
    case rating = "Rating"

    var id: String { self.rawValue }

    var searchParam: String? {
        switch self {
        case .relevance: nil
        case .uploadDate: "CAI="
        case .viewCount: "CAM="
        case .rating: "CAE="
        }
    }
}

// MARK: - YouTubeSearchFilters

struct YouTubeSearchFilters: Equatable, Sendable {
    var type: YouTubeSearchTypeFilter = .all
    var uploadDate: YouTubeSearchUploadDateFilter = .any
    var duration: YouTubeSearchDurationFilter = .any
    var sort: YouTubeSearchSortFilter = .relevance

    var isDefault: Bool {
        self.type == .all && self.uploadDate == .any &&
        self.duration == .any && self.sort == .relevance
    }

    /// Resolved search params string to send to the YouTube InnerTube API.
    ///
    /// YouTube InnerTube's `search` endpoint accepts a single `params` field
    /// containing a base64-encoded protobuf filter payload. Each pre-encoded
    /// value already embeds specific filter bits — the API does NOT support
    /// bitwise combination of arbitrary values. Therefore:
    ///
    /// - Type filter always wins when set (e.g. "Videos", "Channels").
    /// - When type=All, we fall through to sort → date → duration in order.
    ///
    /// Note: combining type + sort/date simultaneously requires building a
    /// custom protobuf payload, which is beyond the scope of current parsers.
    var resolvedParam: String? {
        // Type filter: use it directly when explicitly set
        if self.type != .all, let typeParam = self.type.searchParam {
            return typeParam
        }
        // No type filter: sort takes highest priority (most requested)
        if self.sort != .relevance, let sortParam = self.sort.searchParam {
            return sortParam
        }
        // Upload date filter
        if self.uploadDate != .any, let dateParam = self.uploadDate.searchParam {
            return dateParam
        }
        // Duration filter
        if self.duration != .any, let durationParam = self.duration.searchParam {
            return durationParam
        }
        return nil
    }
}
