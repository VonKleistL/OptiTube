import Foundation

// MARK: - ArtistShelfKind

/// Identifies which carousel shelf an artist-page More/See-all endpoint belongs to.
enum ArtistShelfKind: Hashable, Sendable {
    case albums
    case singles
    case videos
    case episodes
    case livePerformances
    case featuredOn
    case playlistsByArtist
    case podcasts
    case relatedArtists
}

// MARK: - ShelfMoreEndpoint

/// A browse endpoint captured from a carousel shelf's `moreContentButton`.
struct ShelfMoreEndpoint: Hashable, Sendable {
    /// Page-type tags observed in practice on artist-page shelves.
    enum PageType: String, Hashable, Sendable {
        case playlist = "MUSIC_PAGE_TYPE_PLAYLIST"
        case artist = "MUSIC_PAGE_TYPE_ARTIST"
        case discography = "MUSIC_PAGE_TYPE_ARTIST_DISCOGRAPHY"
    }

    let browseId: String
    let params: String?
    let pageType: PageType
}
