import Foundation
import Testing
@testable import OptiTube

/// Tests for the SearchResponseParser.
@Suite("SearchResponseParser", .tags(.parser))
struct SearchResponseParserTests {
    @Test("Parse empty response returns empty results")
    func parseEmptyResponse() {
        let data: [String: Any] = [:]
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.isEmpty)
        #expect(response.albums.isEmpty)
        #expect(response.artists.isEmpty)
        #expect(response.playlists.isEmpty)
    }

    @Test("Parse response with only tracks")
    func parseTrackResults() {
        let data = self.makeSearchResponseData(tracks: 3, albums: 0, artists: 0, playlists: 0)
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.count == 3)
        #expect(response.albums.isEmpty)
        #expect(response.artists.isEmpty)
        #expect(response.playlists.isEmpty)
    }

    @Test("Parse response with only albums")
    func parseAlbumResults() {
        let data = self.makeSearchResponseData(tracks: 0, albums: 2, artists: 0, playlists: 0)
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.isEmpty)
        #expect(response.albums.count == 2)
    }

    @Test("Parse response with only artists")
    func parseArtistResults() {
        let data = self.makeSearchResponseData(tracks: 0, albums: 0, artists: 2, playlists: 0)
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.isEmpty)
        #expect(response.artists.count == 2)
    }

    @Test("Parse response with only playlists")
    func parsePlaylistResults() {
        let data = self.makeSearchResponseData(tracks: 0, albums: 0, artists: 0, playlists: 2)
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.isEmpty)
        #expect(response.playlists.count == 2)
    }

    @Test("Parse response with mixed results")
    func parseMixedResults() {
        let data = self.makeSearchResponseData(tracks: 2, albums: 1, artists: 1, playlists: 1)
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.count == 2)
        #expect(response.albums.count == 1)
        #expect(response.artists.count == 1)
        #expect(response.playlists.count == 1)
    }

    @Test("Track has correct video ID")
    func trackHasVideoId() {
        let data = self.makeSearchResponseData(tracks: 1, albums: 0, artists: 0, playlists: 0)
        let response = SearchResponseParser.parse(data)

        #expect(response.tracks.first?.videoId == "video0")
    }

    // MARK: - Helpers

    private func makeSearchResponseData(tracks: Int, albums: Int, artists: Int, playlists: Int) -> [String: Any] {
        var contents: [[String: Any]] = []

        if tracks > 0 {
            contents.append(["musicShelfRenderer": ["contents": self.makeTrackItems(count: tracks)]])
        }
        if albums > 0 {
            contents.append(["musicShelfRenderer": ["contents": self.makeAlbumItems(count: albums)]])
        }
        if artists > 0 {
            contents.append(["musicShelfRenderer": ["contents": self.makeArtistItems(count: artists)]])
        }
        if playlists > 0 {
            contents.append(["musicShelfRenderer": ["contents": self.makePlaylistItems(count: playlists)]])
        }

        return [
            "contents": [
                "tabbedSearchResultsRenderer": [
                    "tabs": [[
                        "tabRenderer": [
                            "content": [
                                "sectionListRenderer": [
                                    "contents": contents,
                                ],
                            ],
                        ],
                    ]],
                ],
            ],
        ]
    }

    private func makeTrackItems(count: Int) -> [[String: Any]] {
        (0 ..< count).map { i in
            [
                "musicResponsiveListItemRenderer": [
                    "playlistItemData": ["videoId": "video\(i)"],
                    "flexColumns": [
                        ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Track \(i)"]]]]],
                        ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Artist"]]]]],
                    ],
                ],
            ]
        }
    }

    private func makeAlbumItems(count: Int) -> [[String: Any]] {
        (0 ..< count).map { i in
            [
                "musicResponsiveListItemRenderer": [
                    "navigationEndpoint": ["browseEndpoint": ["browseId": "MPRE\(i)"]],
                    "flexColumns": [
                        ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Album \(i)"]]]]],
                    ],
                ],
            ]
        }
    }

    private func makeArtistItems(count: Int) -> [[String: Any]] {
        (0 ..< count).map { i in
            [
                "musicResponsiveListItemRenderer": [
                    "navigationEndpoint": ["browseEndpoint": ["browseId": "UC\(i)"]],
                    "flexColumns": [
                        ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Artist \(i)"]]]]],
                    ],
                ],
            ]
        }
    }

    private func makePlaylistItems(count: Int) -> [[String: Any]] {
        (0 ..< count).map { i in
            [
                "musicResponsiveListItemRenderer": [
                    "navigationEndpoint": ["browseEndpoint": ["browseId": "VL\(i)"]],
                    "flexColumns": [
                        ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Playlist \(i)"]]]]],
                    ],
                ],
            ]
        }
    }
}
