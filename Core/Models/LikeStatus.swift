import Foundation

// MARK: - LikeStatus

/// Represents the like/dislike status of a track in YouTube Music.
enum LikeStatus: String, Codable, Sendable, Equatable {
    /// Track is liked (thumbs up).
    case like = "LIKE"

    /// Track is disliked (thumbs down).
    case dislike = "DISLIKE"

    /// Track has no rating (neutral).
    case indifferent = "INDIFFERENT"

    /// Whether the track is liked.
    var isLiked: Bool {
        self == .like
    }

    /// Whether the track is disliked.
    var isDisliked: Bool {
        self == .dislike
    }
}

// MARK: - FeedbackTokens

/// Tokens used for library add/remove operations.
/// These are obtained from track metadata in API responses.
struct FeedbackTokens: Codable, Hashable, Sendable {
    /// Token to add the track to library.
    let add: String?

    /// Token to remove the track from library.
    let remove: String?

    /// Returns the appropriate token for the desired action.
    func token(forAdding: Bool) -> String? {
        forAdding ? self.add : self.remove
    }
}
