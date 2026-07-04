import Foundation
import Testing
@testable import OptiTube

/// Tests for SearchResponse and SearchResultItem.
@Suite("SearchResponse", .tags(.model))
struct SearchResponseTests {
    // MARK: - SearchResultItem ID Tests

    @Test(
        "Result item ID prefix",
        arguments: [
            ("track", "s1", "track-s1"),
            ("album", "a1", "album-a1"),
            ("artist", "ar1", "artist-ar1"),
            ("playlist", "p1", "playlist-p1"),
        ]
    )
    func resultItemId(type: String, id: String, expectedId: String) {
        let item: SearchResultItem
        switch type {
        case "track":
            item = .track(Track(id: id, title: "Track", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: id))
        case "album":
            item = .album(Album(id: id, title: "Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil))
        case "artist":
            item = .artist(Artist(id: id, name: "Artist"))
        case "playlist":
            item = .playlist(Playlist(id: id, title: "Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: nil))
        default:
            Issue.record("Unknown type")
            return
        }
        #expect(item.id == expectedId)
    }

    // MARK: - SearchResultItem Title Tests

    @Test("Track result item title")
    func trackResultItemTitle() {
        let track = Track(id: "1", title: "My Track", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "1")
        let item = SearchResultItem.track(track)
        #expect(item.title == "My Track")
    }

    @Test("Album result item title")
    func albumResultItemTitle() {
        let album = Album(id: "1", title: "My Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil)
        let item = SearchResultItem.album(album)
        #expect(item.title == "My Album")
    }

    @Test("Artist result item title")
    func artistResultItemTitle() {
        let artist = Artist(id: "1", name: "My Artist")
        let item = SearchResultItem.artist(artist)
        #expect(item.title == "My Artist")
    }

    @Test("Playlist result item title")
    func playlistResultItemTitle() {
        let playlist = Playlist(id: "1", title: "My Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: nil)
        let item = SearchResultItem.playlist(playlist)
        #expect(item.title == "My Playlist")
    }

    // MARK: - SearchResultItem Subtitle Tests

    @Test("Track result item subtitle joins artists")
    func trackResultItemSubtitle() {
        let artists = [Artist(id: "a1", name: "Artist A"), Artist(id: "a2", name: "Artist B")]
        let track = Track(id: "1", title: "Track", artists: artists, album: nil, duration: nil, thumbnailURL: nil, videoId: "1")
        let item = SearchResultItem.track(track)
        #expect(item.subtitle == "Artist A, Artist B")
    }

    @Test("Album result item subtitle")
    func albumResultItemSubtitle() {
        let artists = [Artist(id: "a1", name: "Album Artist")]
        let album = Album(id: "1", title: "Album", artists: artists, thumbnailURL: nil, year: nil, trackCount: nil)
        let item = SearchResultItem.album(album)
        #expect(item.subtitle == "Album Artist")
    }

    @Test("Artist result item subtitle is nil")
    func artistResultItemSubtitle() {
        let artist = Artist(id: "1", name: "Artist Name")
        let item = SearchResultItem.artist(artist)
        // Artist subtitle is nil because resultType already shows "Artist"
        #expect(item.subtitle == nil)
    }

    @Test("Playlist result item subtitle")
    func playlistResultItemSubtitle() {
        let playlist = Playlist(id: "1", title: "Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: "Playlist Author")
        let item = SearchResultItem.playlist(playlist)
        #expect(item.subtitle == "Playlist Author")
    }

    // MARK: - SearchResultItem ThumbnailURL Tests

    @Test("Track result item thumbnail URL")
    func trackResultItemThumbnailURL() {
        let url = URL(string: "https://example.com/track.jpg")
        let track = Track(id: "1", title: "Track", artists: [], album: nil, duration: nil, thumbnailURL: url, videoId: "1")
        let item = SearchResultItem.track(track)
        #expect(item.thumbnailURL == url)
    }

    @Test("Album result item thumbnail URL")
    func albumResultItemThumbnailURL() {
        let url = URL(string: "https://example.com/album.jpg")
        let album = Album(id: "1", title: "Album", artists: nil, thumbnailURL: url, year: nil, trackCount: nil)
        let item = SearchResultItem.album(album)
        #expect(item.thumbnailURL == url)
    }

    @Test("Artist result item thumbnail URL")
    func artistResultItemThumbnailURL() {
        let url = URL(string: "https://example.com/artist.jpg")
        let artist = Artist(id: "1", name: "Artist", thumbnailURL: url)
        let item = SearchResultItem.artist(artist)
        #expect(item.thumbnailURL == url)
    }

    @Test("Playlist result item thumbnail URL")
    func playlistResultItemThumbnailURL() {
        let url = URL(string: "https://example.com/playlist.jpg")
        let playlist = Playlist(id: "1", title: "Playlist", description: nil, thumbnailURL: url, trackCount: nil, author: nil)
        let item = SearchResultItem.playlist(playlist)
        #expect(item.thumbnailURL == url)
    }

    // MARK: - SearchResultItem ResultType Tests

    @Test("Result item result type")
    func resultItemResultType() {
        let track = Track(id: "1", title: "Track", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "1")
        #expect(SearchResultItem.track(track).resultType == "Track")

        let album = Album(id: "1", title: "Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil)
        #expect(SearchResultItem.album(album).resultType == "Album")

        let artist = Artist(id: "1", name: "Artist")
        #expect(SearchResultItem.artist(artist).resultType == "Artist")

        let playlist = Playlist(id: "1", title: "Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: nil)
        #expect(SearchResultItem.playlist(playlist).resultType == "Playlist")
    }

    // MARK: - SearchResultItem VideoId Tests

    @Test("Track result item has video ID")
    func trackResultItemVideoId() {
        let track = Track(id: "1", title: "Track", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "video123")
        let item = SearchResultItem.track(track)
        #expect(item.videoId == "video123")
    }

    @Test("Non-track result items have nil video ID")
    func nonTrackResultItemVideoId() {
        let album = Album(id: "1", title: "Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil)
        #expect(SearchResultItem.album(album).videoId == nil)

        let artist = Artist(id: "1", name: "Artist")
        #expect(SearchResultItem.artist(artist).videoId == nil)

        let playlist = Playlist(id: "1", title: "Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: nil)
        #expect(SearchResultItem.playlist(playlist).videoId == nil)
    }

    // MARK: - SearchResponse Tests

    @Test("SearchResponse empty")
    func searchResponseEmpty() {
        let response = SearchResponse.empty
        #expect(response.isEmpty)
        #expect(response.tracks.isEmpty)
        #expect(response.albums.isEmpty)
        #expect(response.artists.isEmpty)
        #expect(response.playlists.isEmpty)
        #expect(response.allItems.isEmpty)
    }

    @Test("SearchResponse isEmpty")
    func searchResponseIsEmpty() {
        let empty = SearchResponse(tracks: [], albums: [], artists: [], playlists: [])
        #expect(empty.isEmpty)
    }

    @Test("SearchResponse not empty with tracks")
    func searchResponseNotEmptyWithTracks() {
        let track = Track(id: "1", title: "Track", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "1")
        let response = SearchResponse(tracks: [track], albums: [], artists: [], playlists: [])
        #expect(!response.isEmpty)
    }

    @Test("SearchResponse not empty with albums")
    func searchResponseNotEmptyWithAlbums() {
        let album = Album(id: "1", title: "Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil)
        let response = SearchResponse(tracks: [], albums: [album], artists: [], playlists: [])
        #expect(!response.isEmpty)
    }

    @Test("SearchResponse not empty with artists")
    func searchResponseNotEmptyWithArtists() {
        let artist = Artist(id: "1", name: "Artist")
        let response = SearchResponse(tracks: [], albums: [], artists: [artist], playlists: [])
        #expect(!response.isEmpty)
    }

    @Test("SearchResponse not empty with playlists")
    func searchResponseNotEmptyWithPlaylists() {
        let playlist = Playlist(id: "1", title: "Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: nil)
        let response = SearchResponse(tracks: [], albums: [], artists: [], playlists: [playlist])
        #expect(!response.isEmpty)
    }

    @Test("SearchResponse allItems ordering")
    func searchResponseAllItems() {
        let track = Track(id: "s1", title: "Track", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "s1")
        let album = Album(id: "a1", title: "Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil)
        let artist = Artist(id: "ar1", name: "Artist")
        let playlist = Playlist(id: "p1", title: "Playlist", description: nil, thumbnailURL: nil, trackCount: nil, author: nil)

        let response = SearchResponse(tracks: [track], albums: [album], artists: [artist], playlists: [playlist])

        let allItems = response.allItems
        #expect(allItems.count == 4)

        // Check that items are in expected order: tracks, albums, artists, playlists
        #expect(allItems[0].id == "track-s1")
        #expect(allItems[1].id == "album-a1")
        #expect(allItems[2].id == "artist-ar1")
        #expect(allItems[3].id == "playlist-p1")
    }

    @Test("SearchResponse allItems with multiple tracks")
    func searchResponseAllItemsMultiple() {
        let track1 = Track(id: "s1", title: "Track 1", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "s1")
        let track2 = Track(id: "s2", title: "Track 2", artists: [], album: nil, duration: nil, thumbnailURL: nil, videoId: "s2")
        let album = Album(id: "a1", title: "Album", artists: nil, thumbnailURL: nil, year: nil, trackCount: nil)

        let response = SearchResponse(tracks: [track1, track2], albums: [album], artists: [], playlists: [])

        #expect(response.allItems.count == 3)
    }
}
