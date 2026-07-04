import Foundation

// MARK: - SearchResponse

/// Response from a YouTube Music search query.
struct SearchResponse: Sendable {
    let tracks: [Track]
    let videos: [Track]
    let albums: [Album]
    let artists: [Artist]
    let playlists: [Playlist]
    let podcastShows: [PodcastShow]
    /// Continuation token for loading more results (only present for filtered searches).
    let continuationToken: String?

    /// All results as a flat array of items.
    var allItems: [SearchResultItem] {
        var items: [SearchResultItem] = []
        items.append(contentsOf: self.tracks.map { .track($0) })
        items.append(contentsOf: self.videos.map { .video($0) })
        items.append(contentsOf: self.albums.map { .album($0) })
        items.append(contentsOf: self.artists.map { .artist($0) })
        items.append(contentsOf: self.playlists.map { .playlist($0) })
        items.append(contentsOf: self.podcastShows.map { .podcastShow($0) })
        return items
    }

    /// Whether the search returned any results.
    var isEmpty: Bool {
        self.tracks.isEmpty && self.videos.isEmpty && self.albums.isEmpty && self.artists.isEmpty && self.playlists.isEmpty && self.podcastShows.isEmpty
    }

    /// Whether more results are available to load.
    var hasMore: Bool {
        self.continuationToken != nil
    }

    static let empty = SearchResponse(tracks: [], videos: [], albums: [], artists: [], playlists: [], podcastShows: [], continuationToken: nil)

    /// Creates a SearchResponse without continuation token (backward compatibility).
    init(tracks: [Track], albums: [Album], artists: [Artist], playlists: [Playlist]) {
        self.tracks = tracks
        self.videos = []
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
        self.podcastShows = []
        self.continuationToken = nil
    }

    /// Creates a SearchResponse with optional continuation token (backward compatibility).
    init(tracks: [Track], albums: [Album], artists: [Artist], playlists: [Playlist], continuationToken: String?) {
        self.tracks = tracks
        self.videos = []
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
        self.podcastShows = []
        self.continuationToken = continuationToken
    }

    /// Creates a SearchResponse with podcast shows and optional continuation token.
    init(
        tracks: [Track],
        albums: [Album],
        artists: [Artist],
        playlists: [Playlist],
        podcastShows: [PodcastShow],
        continuationToken: String?
    ) {
        self.tracks = tracks
        self.videos = []
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
        self.podcastShows = podcastShows
        self.continuationToken = continuationToken
    }

    init(
        tracks: [Track],
        videos: [Track],
        albums: [Album],
        artists: [Artist],
        playlists: [Playlist],
        podcastShows: [PodcastShow] = [],
        continuationToken: String? = nil
    ) {
        self.tracks = tracks
        self.videos = videos
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
        self.podcastShows = podcastShows
        self.continuationToken = continuationToken
    }
}

// MARK: - SearchResultItem

/// A search result item (can be any content type).
enum SearchResultItem: Identifiable, Sendable {
    case track(Track)
    case video(Track)
    case album(Album)
    case artist(Artist)
    case playlist(Playlist)
    case podcastShow(PodcastShow)

    var id: String {
        switch self {
        case let .track(track):
            "track-\(track.id)"
        case let .video(video):
            "video-\(video.id)"
        case let .album(album):
            "album-\(album.id)"
        case let .artist(artist):
            "artist-\(artist.id)"
        case let .playlist(playlist):
            "playlist-\(playlist.id)"
        case let .podcastShow(show):
            "podcast-\(show.id)"
        }
    }

    var title: String {
        switch self {
        case let .track(track):
            track.title
        case let .video(video):
            video.title
        case let .album(album):
            album.title
        case let .artist(artist):
            artist.name
        case let .playlist(playlist):
            playlist.title
        case let .podcastShow(show):
            show.title
        }
    }

    var subtitle: String? {
        switch self {
        case let .track(track):
            let display = track.artistsDisplay
            return display.isEmpty ? nil : display
        case let .video(video):
            let display = video.artistsDisplay
            return display.isEmpty ? nil : display
        case let .album(album):
            let display = album.artistsDisplay
            return display.isEmpty ? nil : display
        case .artist:
            // No additional subtitle needed - resultType already shows "Artist"
            return nil
        case let .playlist(playlist):
            // Strip "Playlist • " prefix since resultType already shows "Playlist"
            guard let author = playlist.author else { return nil }
            let stripped = author
                .replacingOccurrences(of: "Playlist • ", with: "")
                .trimmingCharacters(in: .whitespaces)
            return stripped.isEmpty ? nil : stripped
        case let .podcastShow(show):
            return show.author
        }
    }

    var thumbnailURL: URL? {
        switch self {
        case let .track(track):
            track.thumbnailURL
        case let .video(video):
            video.thumbnailURL
        case let .album(album):
            album.thumbnailURL
        case let .artist(artist):
            artist.thumbnailURL
        case let .playlist(playlist):
            playlist.thumbnailURL
        case let .podcastShow(show):
            show.thumbnailURL
        }
    }

    var resultType: String {
        switch self {
        case .track:
            L("Track")
        case .video:
            L("Video")
        case .album:
            L("Album")
        case .artist:
            L("Artist")
        case .playlist:
            L("Playlist")
        case .podcastShow:
            L("Podcast")
        }
    }

    /// Returns the video ID if this item is directly playable.
    var videoId: String? {
        switch self {
        case let .track(track):
            track.videoId
        case let .video(video):
            video.videoId
        default:
            nil
        }
    }
}
