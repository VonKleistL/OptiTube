import Foundation
import Testing
@testable import OptiTube

/// Tests for ArtistParser.
@Suite("ArtistParser", .tags(.parser))
struct ArtistParserTests {
    // MARK: - Parse Artist Detail Tests

    @Test("parseArtistDetail extracts basic info")
    func parseArtistDetailBasicInfo() {
        let data = Self.makeArtistResponse(
            name: "Taylor Swift",
            description: "Grammy-winning artist",
            tracks: 5,
            albums: 3
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-taylor")

        #expect(result.name == "Taylor Swift")
        #expect(result.description == "Grammy-winning artist")
        #expect(result.tracks.count == 5)
        #expect(result.albums.count == 3)
    }

    @Test("parseArtistDetail handles empty response")
    func parseArtistDetailEmptyResponse() {
        let data: [String: Any] = [:]

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.name == "Unknown Artist")
        #expect(result.tracks.isEmpty)
        #expect(result.albums.isEmpty)
    }

    @Test("parseArtistDetail extracts channel ID from UC prefix")
    func parseArtistDetailExtractsChannelId() {
        let data = Self.makeArtistResponse(name: "Test Artist", tracks: 0, albums: 0)

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-channel-123")

        #expect(result.channelId == "UC-channel-123")
    }

    @Test("parseArtistDetail does not set channel ID without UC prefix")
    func parseArtistDetailNoChannelIdWithoutPrefix() {
        let data = Self.makeArtistResponse(name: "Test Artist", tracks: 0, albums: 0)

        let result = ArtistParser.parseArtistDetail(data, artistId: "MPLA-not-channel")

        #expect(result.channelId == nil)
    }

    @Test("parseArtistDetail extracts subscription status")
    func parseArtistDetailExtractsSubscription() {
        let data = Self.makeArtistResponseWithSubscription(
            name: "Subscribed Artist",
            isSubscribed: true,
            subscriberCount: "1.5M subscribers"
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.isSubscribed == true)
        #expect(result.subscriberCount == "1.5M subscribers")
    }

    @Test("parseArtistDetail extracts tracks browse ID when available")
    func parseArtistDetailExtractsTracksBrowseId() {
        let data = Self.makeArtistResponseWithMoreTracks(
            browseId: "VLPL-all-tracks",
            params: "some-params"
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.hasMoreTracks == true)
        #expect(result.tracksBrowseId == "VLPL-all-tracks")
        #expect(result.tracksParams == "some-params")
    }

    @Test("parseArtistDetail extracts thumbnail URL")
    func parseArtistDetailExtractsThumbnail() {
        let data = Self.makeArtistResponse(
            name: "Test Artist",
            thumbnailURL: "https://example.com/artist.jpg",
            tracks: 0,
            albums: 0
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.thumbnailURL?.absoluteString == "https://example.com/artist.jpg")
    }

    // MARK: - Parse Artist Tracks Tests

    @Test("parseArtistTracks extracts tracks from shelf")
    func parseArtistTracksExtractsFromShelf() {
        let data = Self.makeArtistTracksResponse(trackCount: 10)

        let tracks = ArtistParser.parseArtistTracks(data)

        #expect(tracks.count == 10)
        #expect(tracks[0].videoId == "video-0")
        #expect(tracks[0].title == "Track 0")
    }

    @Test("parseArtistTracks handles empty response")
    func parseArtistTracksEmptyResponse() {
        let data: [String: Any] = [:]

        let tracks = ArtistParser.parseArtistTracks(data)

        #expect(tracks.isEmpty)
    }

    @Test("parseArtistTracks extracts artist info")
    func parseArtistTracksExtractsArtists() {
        let data = Self.makeArtistTracksResponse(trackCount: 1)

        let tracks = ArtistParser.parseArtistTracks(data)

        #expect(tracks.count == 1)
        #expect(!tracks[0].artists.isEmpty)
    }

    // MARK: - Album Parsing Tests

    @Test("parseArtistDetail extracts albums with MPRE prefix")
    func parseArtistDetailExtractsAlbumsWithMPRE() {
        let data = Self.makeArtistResponseWithAlbums(
            ids: ["MPRE-album-1", "MPRE-album-2"],
            titles: ["Album One", "Album Two"],
            years: ["2024", "2023"]
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.albums.count == 2)
        #expect(result.albums[0].id == "MPRE-album-1")
        #expect(result.albums[0].title == "Album One")
        #expect(result.albums[0].year == "2024")
    }

    @Test("parseArtistDetail extracts albums with OLAK prefix")
    func parseArtistDetailExtractsAlbumsWithOLAK() {
        let data = Self.makeArtistResponseWithAlbums(
            ids: ["OLAK-album-1"],
            titles: ["OLAK Album"],
            years: ["2022"]
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.albums.count == 1)
        #expect(result.albums[0].id == "OLAK-album-1")
    }

    @Test("parseArtistDetail ignores non-album browse IDs")
    func parseArtistDetailIgnoresNonAlbums() {
        let data = Self.makeArtistResponseWithAlbums(
            ids: ["VLPL-playlist"],
            titles: ["Not An Album"],
            years: [nil]
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.albums.isEmpty)
    }

    // MARK: - Mix Playlist Tests

    @Test("parseArtistDetail extracts mix playlist ID from startRadioButton")
    func parseArtistDetailExtractsMixPlaylistId() {
        let data = Self.makeArtistResponseWithRadioButton(
            playlistId: "RDCLAK-mix-123",
            videoId: nil
        )

        let result = ArtistParser.parseArtistDetail(data, artistId: "UC-test")

        #expect(result.mixPlaylistId == "RDCLAK-mix-123")
    }

    // MARK: - Test Helpers

    private static func makeArtistResponse(
        name: String,
        description: String? = nil,
        thumbnailURL: String? = nil,
        tracks: Int,
        albums: Int
    ) -> [String: Any] {
        var headerContent: [String: Any] = [
            "title": [
                "runs": [["text": name]],
            ],
        ]

        if let description {
            headerContent["description"] = [
                "runs": [["text": description]],
            ]
        }

        if let thumbnailURL {
            headerContent["thumbnail"] = [
                "musicThumbnailRenderer": [
                    "thumbnail": [
                        "thumbnails": [
                            ["url": thumbnailURL, "width": 226, "height": 226],
                        ],
                    ],
                ],
            ]
        }

        var sectionContents: [[String: Any]] = []

        // Add tracks shelf
        if tracks > 0 {
            sectionContents.append([
                "musicShelfRenderer": [
                    "contents": Self.makeTrackItems(count: tracks),
                ],
            ])
        }

        // Add albums carousel
        if albums > 0 {
            sectionContents.append([
                "musicCarouselShelfRenderer": [
                    "contents": (0 ..< albums).map { Self.makeAlbumItem(index: $0) },
                ],
            ])
        }

        return [
            "header": [
                "musicImmersiveHeaderRenderer": headerContent,
            ],
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": sectionContents,
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func makeArtistResponseWithSubscription(
        name: String,
        isSubscribed: Bool,
        subscriberCount: String
    ) -> [String: Any] {
        [
            "header": [
                "musicImmersiveHeaderRenderer": [
                    "title": [
                        "runs": [["text": name]],
                    ],
                    "subscriptionButton": [
                        "subscribeButtonRenderer": [
                            "channelId": "UC-extracted",
                            "subscribed": isSubscribed,
                            "subscriberCountText": [
                                "runs": [["text": subscriberCount]],
                            ],
                        ],
                    ],
                ],
            ],
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [] as [[String: Any]],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func makeArtistResponseWithMoreTracks(browseId: String, params: String?) -> [String: Any] {
        var browseEndpoint: [String: Any] = [
            "browseId": browseId,
        ]
        if let params {
            browseEndpoint["params"] = params
        }

        let shelfContent: [String: Any] = [
            "contents": Self.makeTrackItems(count: 5),
            "bottomEndpoint": [
                "browseEndpoint": browseEndpoint,
            ],
        ]

        return [
            "header": [
                "musicImmersiveHeaderRenderer": [
                    "title": [
                        "runs": [["text": "Artist"]],
                    ],
                ],
            ],
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicShelfRenderer": shelfContent,
                                            ],
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func makeAlbumItem(id: String, title: String, year: String?) -> [String: Any] {
        var twoRowRenderer: [String: Any] = [
            "title": [
                "runs": [["text": title]],
            ],
            "navigationEndpoint": [
                "browseEndpoint": [
                    "browseId": id,
                ],
            ],
        ]

        if let year {
            twoRowRenderer["subtitle"] = [
                "runs": [["text": year]],
            ]
        }

        return ["musicTwoRowItemRenderer": twoRowRenderer]
    }

    private static func makeArtistResponseWithAlbums(ids: [String], titles: [String], years: [String?]) -> [String: Any] {
        let albumItems = zip(zip(ids, titles), years).map { pair, year in
            Self.makeAlbumItem(id: pair.0, title: pair.1, year: year)
        }

        return [
            "header": [
                "musicImmersiveHeaderRenderer": [
                    "title": [
                        "runs": [["text": "Artist"]],
                    ],
                ],
            ],
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicCarouselShelfRenderer": [
                                                    "contents": albumItems,
                                                ],
                                            ],
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func makeArtistResponseWithRadioButton(playlistId: String, videoId: String?) -> [String: Any] {
        var watchPlaylistEndpoint: [String: Any] = [
            "playlistId": playlistId,
        ]
        if let videoId {
            watchPlaylistEndpoint["videoId"] = videoId
        }

        return [
            "header": [
                "musicImmersiveHeaderRenderer": [
                    "title": [
                        "runs": [["text": "Artist"]],
                    ],
                    "startRadioButton": [
                        "buttonRenderer": [
                            "navigationEndpoint": [
                                "watchPlaylistEndpoint": watchPlaylistEndpoint,
                            ],
                        ],
                    ],
                ],
            ],
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [] as [[String: Any]],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func makeArtistTracksResponse(trackCount: Int) -> [String: Any] {
        [
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicShelfRenderer": [
                                                    "contents": self.makeTrackItems(count: trackCount),
                                                ],
                                            ],
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private static func makeTrackItems(count: Int) -> [[String: Any]] {
        (0 ..< count).map { index in
            [
                "musicResponsiveListItemRenderer": [
                    "playlistItemData": [
                        "videoId": "video-\(index)",
                    ],
                    "flexColumns": [
                        [
                            "musicResponsiveListItemFlexColumnRenderer": [
                                "text": [
                                    "runs": [["text": "Track \(index)"]],
                                ],
                            ],
                        ],
                        [
                            "musicResponsiveListItemFlexColumnRenderer": [
                                "text": [
                                    "runs": [
                                        [
                                            "text": "Artist \(index)",
                                            "navigationEndpoint": [
                                                "browseEndpoint": [
                                                    "browseId": "UC-artist-\(index)",
                                                ],
                                            ],
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ]
        }
    }

    private static func makeAlbumItem(index: Int) -> [String: Any] {
        [
            "musicTwoRowItemRenderer": [
                "title": [
                    "runs": [["text": "Album \(index)"]],
                ],
                "subtitle": [
                    "runs": [["text": "202\(index)"]],
                ],
                "navigationEndpoint": [
                    "browseEndpoint": [
                        "browseId": "MPRE-\(index)",
                    ],
                ],
            ],
        ]
    }
}
