import Foundation
import Testing
@testable import OptiTube

/// Tests for data models.
@Suite("Models", .tags(.model))
struct ModelTests {
    // MARK: - Track Tests

    @Test("Parses duration from seconds field")
    func trackDurationParsingFromSeconds() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "Test Track",
            "duration_seconds": 185.0,
        ]

        let track = try #require(Track(from: data))
        #expect(track.duration == 185.0)
        #expect(track.durationDisplay == "3:05")
    }

    @Test("Parses duration from string field")
    func trackDurationParsingFromString() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "Test Track",
            "duration": "4:30",
        ]

        let track = try #require(Track(from: data))
        #expect(track.duration == 270.0) // 4 * 60 + 30
    }

    @Test("Parses duration with hours")
    func trackDurationParsingHours() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "Long Track",
            "duration": "1:05:30",
        ]

        let track = try #require(Track(from: data))
        #expect(track.duration == 3930.0) // 1 * 3600 + 5 * 60 + 30
    }

    @Test("Parses multiple artists correctly")
    func trackWithMultipleArtists() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "Collab Track",
            "artists": [
                ["name": "Artist One", "id": "A1"],
                ["name": "Artist Two", "id": "A2"],
                ["name": "Artist Three", "id": "A3"],
            ],
        ]

        let track = try #require(Track(from: data))
        #expect(track.artists.count == 3)
        #expect(track.artistsDisplay == "Artist One, Artist Two, Artist Three")
    }

    @Test("Handles track with no artists")
    func trackWithNoArtists() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "No Artists Track",
        ]

        let track = try #require(Track(from: data))
        #expect(track.artists.isEmpty)
        #expect(track.artistsDisplay.isEmpty)
    }

    @Test("Parses album from track data")
    func trackWithAlbum() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "Album Track",
            "album": [
                "browseId": "album123",
                "title": "Test Album",
            ],
        ]

        let track = try #require(Track(from: data))
        #expect(track.album != nil)
        #expect(track.album?.title == "Test Album")
    }

    @Test("Uses largest thumbnail from array")
    func trackWithThumbnails() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "Thumbnail Track",
            "thumbnails": [
                ["url": "https://example.com/small.jpg", "width": 60, "height": 60],
                ["url": "https://example.com/large.jpg", "width": 400, "height": 400],
            ],
        ]

        let track = try #require(Track(from: data))
        #expect(track.thumbnailURL?.absoluteString == "https://example.com/large.jpg")
    }

    @Test("Uses default title when missing")
    func trackDefaultTitle() throws {
        let data: [String: Any] = [
            "videoId": "test123",
        ]

        let track = try #require(Track(from: data))
        #expect(track.title == "Unknown Title")
    }

    @Test("Handles missing duration")
    func trackNoDuration() throws {
        let data: [String: Any] = [
            "videoId": "test123",
            "title": "No Duration",
        ]

        let track = try #require(Track(from: data))
        #expect(track.duration == nil)
        #expect(track.durationDisplay == "--:--")
    }

    @Test("Track is Hashable")
    func trackHashable() {
        let track1 = Track(
            id: "test",
            title: "Test",
            artists: [],
            album: nil,
            duration: nil,
            thumbnailURL: nil,
            videoId: "test"
        )

        let track2 = Track(
            id: "test",
            title: "Test",
            artists: [],
            album: nil,
            duration: nil,
            thumbnailURL: nil,
            videoId: "test"
        )

        #expect(track1 == track2)

        var set: Set<Track> = []
        set.insert(track1)
        set.insert(track2)
        #expect(set.count == 1)
    }

    // MARK: - Playlist Tests

    @Test(
        "Detects album prefixes correctly",
        arguments: [
            ("OLAK5uy_abc", true),
            ("MPREb_xyz123", true),
            ("PLtest123", false),
        ]
    )
    func playlistIsAlbum(id: String, expectedIsAlbum: Bool) {
        let playlist = Playlist(
            id: id,
            title: "Title",
            description: nil,
            thumbnailURL: nil,
            trackCount: 10,
            author: nil
        )

        #expect(playlist.isAlbum == expectedIsAlbum)
    }

    @Test(
        "Formats track count display correctly",
        arguments: [
            (1, "1 track"),
            (25, "25 tracks"),
        ]
    )
    func playlistTrackCountDisplay(count: Int, expected: String) {
        let playlist = Playlist(
            id: "PL1",
            title: "Playlist",
            description: nil,
            thumbnailURL: nil,
            trackCount: count,
            author: nil
        )
        #expect(playlist.trackCountDisplay == expected)
    }

    @Test("Returns empty string for nil track count")
    func playlistTrackCountDisplayNil() {
        let playlist = Playlist(
            id: "PL3",
            title: "No Count",
            description: nil,
            thumbnailURL: nil,
            trackCount: nil,
            author: nil
        )
        #expect(playlist.trackCountDisplay.isEmpty)
    }

    @Test("Parses playlist with browseId")
    func playlistParsingWithBrowseId() throws {
        let data: [String: Any] = [
            "browseId": "browse123",
            "title": "Browse Playlist",
        ]

        let playlist = try #require(Playlist(from: data))
        #expect(playlist.id == "browse123")
    }

    @Test("Parses author from authors array")
    func playlistParsingWithAuthors() throws {
        let data: [String: Any] = [
            "playlistId": "PL123",
            "title": "Authored Playlist",
            "authors": [
                ["name": "Playlist Creator"],
            ],
        ]

        let playlist = try #require(Playlist(from: data))
        #expect(playlist.author == "Playlist Creator")
    }

    @Test("Parses author from string field")
    func playlistParsingWithAuthorString() throws {
        let data: [String: Any] = [
            "playlistId": "PL123",
            "title": "Authored Playlist",
            "author": "Direct Author",
        ]

        let playlist = try #require(Playlist(from: data))
        #expect(playlist.author == "Direct Author")
    }

    @Test("Parses track count from formatted string")
    func playlistParsingTrackCountString() throws {
        let data: [String: Any] = [
            "playlistId": "PL123",
            "title": "Playlist",
            "trackCount": "1,234",
        ]

        let playlist = try #require(Playlist(from: data))
        #expect(playlist.trackCount == 1234)
    }

    @Test("Returns nil for playlist with no ID")
    func playlistWithNoId() {
        let data: [String: Any] = [
            "title": "No ID Playlist",
        ]

        let playlist = Playlist(from: data)
        #expect(playlist == nil)
    }

    // MARK: - PlaylistDetail Tests

    @Test("Creates PlaylistDetail from Playlist")
    func playlistDetailFromPlaylist() {
        let playlist = Playlist(
            id: "PL123",
            title: "Test Playlist",
            description: "A description",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            trackCount: 5,
            author: "Test Author"
        )

        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
        ]

        let detail = PlaylistDetail(playlist: playlist, tracks: tracks, duration: "6:20")

        #expect(detail.id == "PL123")
        #expect(detail.title == "Test Playlist")
        #expect(detail.description == "A description")
        #expect(detail.author == "Test Author")
        #expect(detail.tracks.count == 2)
        #expect(detail.duration == "6:20")
    }

    @Test("PlaylistDetail inherits isAlbum from playlist")
    func playlistDetailIsAlbum() {
        let albumPlaylist = Playlist(
            id: "OLAK5uy_abc",
            title: "Album",
            description: nil,
            thumbnailURL: nil,
            trackCount: 10,
            author: nil
        )

        let detail = PlaylistDetail(playlist: albumPlaylist, tracks: [])
        #expect(detail.isAlbum)
    }

    // MARK: - Album Tests

    @Test("Formats multiple artists display")
    func albumArtistsDisplay() {
        let artists = [
            Artist(id: "a1", name: "Artist A"),
            Artist(id: "a2", name: "Artist B"),
        ]

        let album = Album(
            id: "album1",
            title: "Multi-Artist Album",
            artists: artists,
            thumbnailURL: nil,
            year: "2024",
            trackCount: 12
        )

        #expect(album.artistsDisplay == "Artist A, Artist B")
    }

    @Test("Returns empty string for nil artists")
    func albumNoArtistsDisplay() {
        let album = Album(
            id: "album1",
            title: "No Artist Album",
            artists: nil,
            thumbnailURL: nil,
            year: "2024",
            trackCount: 12
        )

        #expect(album.artistsDisplay.isEmpty)
    }

    @Test("Parses album with albumId")
    func albumParsingWithAlbumId() throws {
        let data: [String: Any] = [
            "albumId": "ALBUM123",
            "title": "Album via albumId",
        ]

        let album = try #require(Album(from: data))
        #expect(album.id == "ALBUM123")
    }

    @Test("Parses album with id field")
    func albumParsingWithId() throws {
        let data: [String: Any] = [
            "id": "ID123",
            "title": "Album via id",
        ]

        let album = try #require(Album(from: data))
        #expect(album.id == "ID123")
    }

    @Test("Parses inline album reference with name only")
    func albumParsingInlineReference() throws {
        let data: [String: Any] = [
            "name": "Referenced Album",
        ]

        let album = try #require(Album(from: data))
        #expect(album.title == "Referenced Album")
        #expect(!album.id.isEmpty)
    }

    @Test("Parses album with artists array")
    func albumParsingWithArtists() throws {
        let data: [String: Any] = [
            "browseId": "ALBUM123",
            "title": "Album with Artists",
            "artists": [
                ["name": "Artist One", "id": "A1"],
            ],
        ]

        let album = try #require(Album(from: data))
        #expect(album.artists?.count == 1)
        #expect(album.artists?.first?.name == "Artist One")
    }

    @Test("Parses year field")
    func albumParsingWithYear() throws {
        let data: [String: Any] = [
            "browseId": "ALBUM123",
            "title": "Album",
            "year": "2023",
        ]

        let album = try #require(Album(from: data))
        #expect(album.year == "2023")
    }

    @Test("Uses default title when missing")
    func albumDefaultTitle() throws {
        let data: [String: Any] = [
            "browseId": "ALBUM123",
        ]

        let album = try #require(Album(from: data))
        #expect(album.title == "Unknown Album")
    }

    @Test("Uses name field as title")
    func albumWithNameAsTitle() throws {
        let data: [String: Any] = [
            "browseId": "ALBUM123",
            "name": "Album Name",
        ]

        let album = try #require(Album(from: data))
        #expect(album.title == "Album Name")
    }

    @Test("Returns nil when no ID or name")
    func albumNoIdOrName() {
        let data: [String: Any] = [
            "someOther": "field",
        ]

        let album = Album(from: data)
        #expect(album == nil)
    }

    // MARK: - Artist Tests

    @Test("Parses artist with thumbnail")
    func artistWithThumbnail() throws {
        let data: [String: Any] = [
            "browseId": "UC123",
            "name": "Artist with Thumb",
            "thumbnails": [
                ["url": "https://example.com/artist.jpg"],
            ],
        ]

        let artist = try #require(Artist(from: data))
        #expect(artist.thumbnailURL?.absoluteString == "https://example.com/artist.jpg")
    }

    @Test("Parses artist with id field")
    func artistWithId() throws {
        let data: [String: Any] = [
            "id": "ID123",
            "name": "Artist via id",
        ]

        let artist = try #require(Artist(from: data))
        #expect(artist.id == "ID123")
    }

    @Test("Parses artist with browseId")
    func artistWithBrowseId() throws {
        let data: [String: Any] = [
            "browseId": "UC456",
            "name": "Artist via browseId",
        ]

        let artist = try #require(Artist(from: data))
        #expect(artist.id == "UC456")
    }

    @Test("Generates UUID for inline artist")
    func artistFallbackId() throws {
        let data: [String: Any] = [
            "name": "Inline Artist",
        ]

        let artist = try #require(Artist(from: data))
        #expect(!artist.id.isEmpty)
    }

    @Test("Uses default name when missing")
    func artistDefaultName() throws {
        let data: [String: Any] = [
            "id": "123",
        ]

        let artist = try #require(Artist(from: data))
        #expect(artist.name == "Unknown Artist")
    }

    @Test("Direct initializer sets all properties")
    func artistInitializer() {
        let artist = Artist(id: "A1", name: "Test Artist", thumbnailURL: URL(string: "https://example.com/a.jpg"))

        #expect(artist.id == "A1")
        #expect(artist.name == "Test Artist")
        #expect(artist.thumbnailURL?.absoluteString == "https://example.com/a.jpg")
    }

    @Test("Artist is Hashable")
    func artistHashable() {
        let artist1 = Artist(id: "A1", name: "Artist")
        let artist2 = Artist(id: "A1", name: "Artist")

        #expect(artist1 == artist2)

        var set: Set<Artist> = []
        set.insert(artist1)
        set.insert(artist2)
        #expect(set.count == 1)
    }

    // MARK: - What's New Tests

    @Test("WhatsNew version parses semantic and suffix components")
    func whatsNewVersionParsing() {
        let version: WhatsNew.Version = "1.2.3-beta.1"
        #expect(version.major == 1)
        #expect(version.minor == 2)
        #expect(version.patch == 3)
        #expect(version.description == "1.2.3-beta.1")
    }

    @Test("WhatsNew version comparison orders prerelease before stable")
    func whatsNewVersionComparison() {
        let prerelease: WhatsNew.Version = "2.0.0-beta.1"
        let stable: WhatsNew.Version = "2.0.0"
        #expect(prerelease < stable)
    }

    @Test("WhatsNew version store marks versions as presented")
    func whatsNewVersionStorePersistence() {
        let suiteName = "whatsnew-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = WhatsNewVersionStore(defaults: defaults)
        let version: WhatsNew.Version = "1.0.0"

        #expect(store.hasPresented(version) == false)
        store.markPresented(version)
        #expect(store.hasPresented(version))

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("WhatsNew static provider respects presented-version gating")
    func whatsNewStaticProviderRespectsPresentedVersions() {
        let suiteName = "whatsnew-provider-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = WhatsNewVersionStore(defaults: defaults)
        let version: WhatsNew.Version = "1.0.0"

        let first = WhatsNewProvider.staticWhatsNew(
            for: version,
            store: store,
            respectingPresentedVersions: true
        )
        #expect(first != nil)

        store.markPresented(version)
        let second = WhatsNewProvider.staticWhatsNew(
            for: version,
            store: store,
            respectingPresentedVersions: true
        )
        #expect(second == nil)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("WhatsNew release notes cleanup removes wrapper sections")
    func whatsNewReleaseNotesCleanup() {
        let raw = """
        Intro

        ## What's New

        - Added queue persistence

        ## New Contributors

        - @someone
        """

        let cleaned = WhatsNewProvider.cleanReleaseBody(raw)
        #expect(cleaned.contains("Added queue persistence"))
        #expect(cleaned.contains("New Contributors") == false)
    }

    @Test("WhatsNew parses GitHub release payload into an entry")
    func whatsNewParsesGitHubReleasePayload() throws {
        let payload = Data(#"""
        {
          "tag_name": "v2.4.0",
          "name": "OptiTube 2.4",
          "body": "## What's New\n\n- Added queue persistence\n\n## New Contributors\n\n- @someone",
          "html_url": "https://github.com/VonKleistL/OptiTube/releases/tag/v2.4.0"
        }
        """#.utf8)

        let entry = WhatsNewProvider.parseRelease(data: payload)

        #expect(entry?.version.description == "2.4.0")
        #expect(entry?.title == "OptiTube 2.4")
        #expect(entry?.releaseNotes?.contains("Added queue persistence") == true)
        #expect(entry?.releaseNotes?.contains("New Contributors") == false)
        #expect(entry?.learnMoreURL?.absoluteString == "https://github.com/VonKleistL/OptiTube/releases/tag/v2.4.0")
    }

    @Test("WhatsNew falls back to formatted title when GitHub release name is missing")
    func whatsNewUsesFallbackTitleForUnnamedRelease() throws {
        let payload = Data(#"""
        {
          "tag_name": "v2.5.1",
          "body": "- Added synced lyrics",
          "html_url": "https://github.com/VonKleistL/OptiTube/releases/tag/v2.5.1"
        }
        """#.utf8)

        let entry = WhatsNewProvider.parseRelease(data: payload)

        #expect(entry?.title == "What's New in OptiTube 2.5.1")
        #expect(entry?.releaseNotes == "- Added synced lyrics")
    }
}
