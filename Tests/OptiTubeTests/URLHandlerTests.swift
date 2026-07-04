import Foundation
import Testing
@testable import OptiTube

// MARK: - URLHandlerTests

@Suite("URL Handler Tests")
struct URLHandlerTests {
    // MARK: - YouTube Music URL Tests

    @Test("Parse watch URL extracts video ID")
    func parseWatchURL() {
        let url = URL(string: "https://music.youtube.com/watch?v=dQw4w9WgXcQ")!
        let result = URLHandler.parse(url)

        guard case let .track(videoId) = result else {
            Issue.record("Expected track result")
            return
        }
        #expect(videoId == "dQw4w9WgXcQ")
    }

    @Test("Parse playlist URL extracts playlist ID")
    func parsePlaylistURL() {
        let url = URL(string: "https://music.youtube.com/playlist?list=PLtest123")!
        let result = URLHandler.parse(url)

        guard case let .playlist(id) = result else {
            Issue.record("Expected playlist result")
            return
        }
        #expect(id == "PLtest123")
    }

    @Test("Parse album browse URL extracts album ID")
    func parseAlbumBrowseURL() {
        let url = URL(string: "https://music.youtube.com/browse/MPREb_test123")!
        let result = URLHandler.parse(url)

        guard case let .album(id) = result else {
            Issue.record("Expected album result")
            return
        }
        #expect(id == "MPREb_test123")
    }

    @Test("Parse OLAK album browse URL extracts album ID")
    func parseOLAKAlbumBrowseURL() {
        let url = URL(string: "https://music.youtube.com/browse/OLAK5uy_test456")!
        let result = URLHandler.parse(url)

        guard case let .album(id) = result else {
            Issue.record("Expected album result")
            return
        }
        #expect(id == "OLAK5uy_test456")
    }

    @Test("Parse playlist browse URL (VLPL format) extracts playlist ID")
    func parsePlaylistBrowseURL() {
        let url = URL(string: "https://music.youtube.com/browse/VLPLtest789")!
        let result = URLHandler.parse(url)

        guard case let .playlist(id) = result else {
            Issue.record("Expected playlist result")
            return
        }
        #expect(id == "PLtest789")
    }

    @Test("Parse channel URL extracts artist ID")
    func parseChannelURL() {
        let url = URL(string: "https://music.youtube.com/channel/UCuAXFkgsw1L7xaCfnd5JJOw")!
        let result = URLHandler.parse(url)

        guard case let .artist(id) = result else {
            Issue.record("Expected artist result")
            return
        }
        #expect(id == "UCuAXFkgsw1L7xaCfnd5JJOw")
    }

    @Test("Parse browse URL with UC prefix extracts as artist")
    func parseBrowseArtistURL() {
        let url = URL(string: "https://music.youtube.com/browse/UCtest123")!
        let result = URLHandler.parse(url)

        guard case let .artist(id) = result else {
            Issue.record("Expected artist result")
            return
        }
        #expect(id == "UCtest123")
    }

    // MARK: - Custom Scheme Tests

    @Test("Parse optitube://play URL extracts video ID")
    func parseOptiTubePlayURL() {
        let url = URL(string: "optitube://play?v=abc123")!
        let result = URLHandler.parse(url)

        guard case let .track(videoId) = result else {
            Issue.record("Expected track result")
            return
        }
        #expect(videoId == "abc123")
    }

    @Test("Parse optitube://playlist URL extracts playlist ID")
    func parseOptiTubePlaylistURL() {
        let url = URL(string: "optitube://playlist?list=PLmylist")!
        let result = URLHandler.parse(url)

        guard case let .playlist(id) = result else {
            Issue.record("Expected playlist result")
            return
        }
        #expect(id == "PLmylist")
    }

    @Test("Parse optitube://album URL extracts album ID")
    func parseOptiTubeAlbumURL() {
        let url = URL(string: "optitube://album?id=MPREb_album")!
        let result = URLHandler.parse(url)

        guard case let .album(id) = result else {
            Issue.record("Expected album result")
            return
        }
        #expect(id == "MPREb_album")
    }

    @Test("Parse optitube://artist URL extracts artist ID")
    func parseOptiTubeArtistURL() {
        let url = URL(string: "optitube://artist?id=UCchannel")!
        let result = URLHandler.parse(url)

        guard case let .artist(id) = result else {
            Issue.record("Expected artist result")
            return
        }
        #expect(id == "UCchannel")
    }

    // MARK: - Invalid URL Tests

    @Test("Unrecognized URL returns nil")
    func parseUnrecognizedURL() {
        let url = URL(string: "https://example.com/test")!
        let result = URLHandler.parse(url)

        #expect(result == nil)
    }

    @Test("YouTube Music URL without parameters returns nil")
    func parseYTMusicWithoutParams() {
        let url = URL(string: "https://music.youtube.com/watch")!
        let result = URLHandler.parse(url)

        #expect(result == nil)
    }

    @Test("Empty video ID returns nil")
    func parseEmptyVideoID() {
        let url = URL(string: "https://music.youtube.com/watch?v=")!
        let result = URLHandler.parse(url)

        #expect(result == nil)
    }

    @Test("Regular YouTube URL is not recognized")
    func parseRegularYouTubeURL() {
        let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        let result = URLHandler.parse(url)

        #expect(result == nil)
    }
}
