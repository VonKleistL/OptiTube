import Foundation

// MARK: - TopTracksDestination

/// Navigation destination for viewing all top tracks of an artist.
struct TopTracksDestination: Hashable, Sendable {
    let artistId: String
    let artistName: String
    let tracks: [Track]
    /// Browse ID for loading all tracks (if more are available).
    let tracksBrowseId: String?
    /// Params for loading all tracks.
    let tracksParams: String?
}
