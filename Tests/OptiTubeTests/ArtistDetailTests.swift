import Foundation
import Testing
@testable import OptiTube

/// Tests for ArtistDetail.
@Suite("ArtistDetail", .tags(.viewModel))
struct ArtistDetailTests {
    @Test("ArtistDetail initialization")
    func artistDetailInit() {
        let artist = Artist(id: "UC123", name: "Test Artist", thumbnailURL: URL(string: "https://example.com/a.jpg"))
        let tracks = [
            Track(id: "s1", title: "Track 1", artists: [artist], album: nil, duration: 180, thumbnailURL: nil, videoId: "s1"),
            Track(id: "s2", title: "Track 2", artists: [artist], album: nil, duration: 200, thumbnailURL: nil, videoId: "s2"),
        ]
        let albums = [
            Album(id: "a1", title: "Album 1", artists: [artist], thumbnailURL: nil, year: "2023", trackCount: 10),
        ]

        let detail = ArtistDetail(
            artist: artist,
            description: "A great artist",
            tracks: tracks,
            albums: albums,
            thumbnailURL: URL(string: "https://example.com/large.jpg")
        )

        #expect(detail.id == "UC123")
        #expect(detail.name == "Test Artist")
        #expect(detail.description == "A great artist")
        #expect(detail.tracks.count == 2)
        #expect(detail.albums.count == 1)
        #expect(detail.thumbnailURL?.absoluteString == "https://example.com/large.jpg")
    }

    @Test("ArtistDetail id computed property")
    func artistDetailIdComputedProperty() {
        let artist = Artist(id: "artist_id_123", name: "Artist")
        let detail = ArtistDetail(artist: artist, description: nil, tracks: [], albums: [], thumbnailURL: nil)
        #expect(detail.id == "artist_id_123")
    }

    @Test("ArtistDetail name computed property")
    func artistDetailNameComputedProperty() {
        let artist = Artist(id: "1", name: "Famous Artist Name")
        let detail = ArtistDetail(artist: artist, description: nil, tracks: [], albums: [], thumbnailURL: nil)
        #expect(detail.name == "Famous Artist Name")
    }

    @Test("ArtistDetail with no description")
    func artistDetailWithNoDescription() {
        let artist = Artist(id: "1", name: "Artist")
        let detail = ArtistDetail(artist: artist, description: nil, tracks: [], albums: [], thumbnailURL: nil)
        #expect(detail.description == nil)
    }

    @Test("ArtistDetail with empty tracks and albums")
    func artistDetailWithEmptyTracksAndAlbums() {
        let artist = Artist(id: "1", name: "New Artist")
        let detail = ArtistDetail(artist: artist, description: "Just starting out", tracks: [], albums: [], thumbnailURL: nil)
        #expect(detail.tracks.isEmpty)
        #expect(detail.albums.isEmpty)
    }

    @Test("ArtistDetail artist property")
    func artistDetailArtistProperty() {
        let artist = Artist(id: "UC123", name: "Artist", thumbnailURL: URL(string: "https://example.com/thumb.jpg"))
        let detail = ArtistDetail(artist: artist, description: nil, tracks: [], albums: [], thumbnailURL: nil)

        #expect(detail.artist.id == "UC123")
        #expect(detail.artist.name == "Artist")
        #expect(detail.artist.thumbnailURL != nil)
    }
}
