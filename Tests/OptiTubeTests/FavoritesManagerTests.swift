import Foundation
import Testing
@testable import OptiTube

/// Tests for FavoritesManager using Swift Testing.
@Suite("FavoritesManager", .serialized, .tags(.service), .timeLimit(.minutes(1)))
@MainActor
struct FavoritesManagerTests {
    // Use a fresh manager for each test (skipLoad to avoid disk state)
    var manager: FavoritesManager

    init() {
        self.manager = FavoritesManager(skipLoad: true)
    }

    // MARK: - Basic Operations

    @Test("Initial state is empty")
    func initialState() {
        #expect(self.manager.items.isEmpty)
        #expect(self.manager.isVisible == false)
    }

    @Test("Add track succeeds")
    func addTrack() {
        let track = TestFixtures.makeTrack(id: "test-track-1")
        let item = FavoriteItem.from(track)

        self.manager.add(item)

        #expect(self.manager.items.count == 1)
        #expect(self.manager.isVisible == true)
        #expect(self.manager.isPinned(track: track) == true)
    }

    @Test("Add album succeeds")
    func addAlbum() {
        let album = TestFixtures.makeAlbum(id: "MPRE-test-album")
        let item = FavoriteItem.from(album)

        self.manager.add(item)

        #expect(self.manager.items.count == 1)
        #expect(self.manager.isPinned(album: album) == true)
    }

    @Test("Add playlist succeeds")
    func addPlaylist() {
        let playlist = TestFixtures.makePlaylist(id: "VL-test-playlist")
        let item = FavoriteItem.from(playlist)

        self.manager.add(item)

        #expect(self.manager.items.count == 1)
        #expect(self.manager.isPinned(playlist: playlist) == true)
    }

    @Test("Add artist succeeds")
    func addArtist() {
        let artist = TestFixtures.makeArtist(id: "UC-test-artist")
        let item = FavoriteItem.from(artist)

        self.manager.add(item)

        #expect(self.manager.items.count == 1)
        #expect(self.manager.isPinned(artist: artist) == true)
    }

    @Test("Add duplicate is ignored")
    func addDuplicateIgnored() {
        let track = TestFixtures.makeTrack(id: "duplicate-track")
        let item1 = FavoriteItem.from(track)
        let item2 = FavoriteItem.from(track)

        self.manager.add(item1)
        self.manager.add(item2)

        #expect(self.manager.items.count == 1)
    }

    @Test("New items added to front")
    func newItemsAddedToFront() {
        let track1 = TestFixtures.makeTrack(id: "track-1", title: "First Track")
        let track2 = TestFixtures.makeTrack(id: "track-2", title: "Second Track")

        self.manager.add(.from(track1))
        self.manager.add(.from(track2))

        #expect(self.manager.items.count == 2)
        #expect(self.manager.items[0].title == "Second Track")
        #expect(self.manager.items[1].title == "First Track")
    }

    // MARK: - Remove Operations

    @Test("Remove by contentId succeeds")
    func removeByContentId() {
        let track = TestFixtures.makeTrack(id: "remove-test")
        self.manager.add(.from(track))
        #expect(self.manager.items.count == 1)

        self.manager.remove(contentId: track.videoId)

        #expect(self.manager.items.isEmpty)
        #expect(self.manager.isPinned(track: track) == false)
    }

    @Test("Remove non-existent item is no-op")
    func removeNonExistent() {
        let track = TestFixtures.makeTrack(id: "existing")
        self.manager.add(.from(track))

        self.manager.remove(contentId: "non-existent")

        #expect(self.manager.items.count == 1)
    }

    // MARK: - Toggle Operations

    @Test("Toggle adds then removes")
    func toggleAddsAndRemoves() {
        let track = TestFixtures.makeTrack(id: "toggle-test")

        // First toggle should add
        self.manager.toggle(track: track)
        #expect(self.manager.isPinned(track: track) == true)
        #expect(self.manager.items.count == 1)

        // Second toggle should remove
        self.manager.toggle(track: track)
        #expect(self.manager.isPinned(track: track) == false)
        #expect(self.manager.items.isEmpty)
    }

    // MARK: - Move Operations

    @Test("Move item changes position")
    func moveItem() {
        let track1 = TestFixtures.makeTrack(id: "move-1", title: "Track 1")
        let track2 = TestFixtures.makeTrack(id: "move-2", title: "Track 2")
        let track3 = TestFixtures.makeTrack(id: "move-3", title: "Track 3")

        self.manager.add(.from(track1))
        self.manager.add(.from(track2))
        self.manager.add(.from(track3))

        // Order is now: track3, track2, track1 (newest first)
        #expect(self.manager.items[0].title == "Track 3")
        #expect(self.manager.items[1].title == "Track 2")
        #expect(self.manager.items[2].title == "Track 1")

        // Move track1 (index 2) to index 0
        self.manager.move(from: IndexSet(integer: 2), to: 0)

        #expect(self.manager.items[0].title == "Track 1")
        #expect(self.manager.items[1].title == "Track 3")
        #expect(self.manager.items[2].title == "Track 2")
    }

    @Test("Move to top succeeds")
    func moveToTop() {
        let track1 = TestFixtures.makeTrack(id: "top-1", title: "Track 1")
        let track2 = TestFixtures.makeTrack(id: "top-2", title: "Track 2")
        let track3 = TestFixtures.makeTrack(id: "top-3", title: "Track 3")

        self.manager.add(.from(track1))
        self.manager.add(.from(track2))
        self.manager.add(.from(track3))

        // Order is: track3, track2, track1
        // Move track1 to top
        self.manager.moveToTop(contentId: track1.videoId)

        #expect(self.manager.items[0].title == "Track 1")
    }

    @Test("Move to end succeeds")
    func moveToEnd() {
        let track1 = TestFixtures.makeTrack(id: "end-1", title: "Track 1")
        let track2 = TestFixtures.makeTrack(id: "end-2", title: "Track 2")
        let track3 = TestFixtures.makeTrack(id: "end-3", title: "Track 3")

        self.manager.add(.from(track1))
        self.manager.add(.from(track2))
        self.manager.add(.from(track3))

        // Order is: track3, track2, track1
        // Move track3 to end
        self.manager.moveToEnd(contentId: track3.videoId)

        #expect(self.manager.items[2].title == "Track 3")
    }

    // MARK: - isPinned Checks

    @Test("isPinned returns correct state")
    func isPinnedReturnsCorrectState() {
        let track = TestFixtures.makeTrack(id: "pinned-test")

        #expect(self.manager.isPinned(track: track) == false)
        #expect(self.manager.isPinned(contentId: track.videoId) == false)

        self.manager.add(.from(track))

        #expect(self.manager.isPinned(track: track) == true)
        #expect(self.manager.isPinned(contentId: track.videoId) == true)
    }

    // MARK: - Clear All

    @Test("Clear all removes all items")
    func clearAllRemovesAll() {
        self.manager.add(.from(TestFixtures.makeTrack(id: "clear-1")))
        self.manager.add(.from(TestFixtures.makeTrack(id: "clear-2")))
        self.manager.add(.from(TestFixtures.makeTrack(id: "clear-3")))

        #expect(self.manager.items.count == 3)

        self.manager.clearAll()

        #expect(self.manager.items.isEmpty)
        #expect(self.manager.isVisible == false)
    }

    // MARK: - FavoriteItem Model Tests

    @Test("FavoriteItem contentId returns correct value")
    func favoriteItemContentId() {
        let track = TestFixtures.makeTrack(id: "content-id-test")
        let album = TestFixtures.makeAlbum(id: "MPRE-content-album")
        let playlist = TestFixtures.makePlaylist(id: "VL-content-playlist")
        let artist = TestFixtures.makeArtist(id: "UC-content-artist")

        let trackItem = FavoriteItem.from(track)
        let albumItem = FavoriteItem.from(album)
        let playlistItem = FavoriteItem.from(playlist)
        let artistItem = FavoriteItem.from(artist)

        #expect(trackItem.contentId == track.videoId)
        #expect(albumItem.contentId == album.id)
        #expect(playlistItem.contentId == playlist.id)
        #expect(artistItem.contentId == artist.id)
    }

    @Test("FavoriteItem title returns correct value")
    func favoriteItemTitle() {
        let track = TestFixtures.makeTrack(title: "Test Track Title")
        let album = TestFixtures.makeAlbum(title: "Test Album Title")

        let trackItem = FavoriteItem.from(track)
        let albumItem = FavoriteItem.from(album)

        #expect(trackItem.title == "Test Track Title")
        #expect(albumItem.title == "Test Album Title")
    }

    @Test("FavoriteItem subtitle returns correct value")
    func favoriteItemSubtitle() {
        let track = TestFixtures.makeTrack(artistName: "Test Artist")
        let album = TestFixtures.makeAlbum(artistName: "Album Artist")

        let trackItem = FavoriteItem.from(track)
        let albumItem = FavoriteItem.from(album)

        #expect(trackItem.subtitle == "Test Artist")
        #expect(albumItem.subtitle == "Album Artist")
    }

    @Test("FavoriteItem typeLabel returns correct value")
    func favoriteItemTypeLabel() {
        let trackItem = FavoriteItem.from(TestFixtures.makeTrack())
        let albumItem = FavoriteItem.from(TestFixtures.makeAlbum())
        let playlistItem = FavoriteItem.from(TestFixtures.makePlaylist())
        let artistItem = FavoriteItem.from(TestFixtures.makeArtist())

        #expect(trackItem.typeLabel == "Track")
        #expect(albumItem.typeLabel == "Album")
        #expect(playlistItem.typeLabel == "Playlist")
        #expect(artistItem.typeLabel == "Artist")
    }

    @Test("FavoriteItem equality based on contentId")
    func favoriteItemEquality() {
        let track = TestFixtures.makeTrack(id: "same-id")
        let item1 = FavoriteItem.from(track)
        let item2 = FavoriteItem.from(track)

        // Should be equal even though they have different UUIDs
        #expect(item1 == item2)
        #expect(item1.hashValue == item2.hashValue)
    }

    @Test("FavoriteItem asHomeSectionItem conversion")
    func favoriteItemAsHomeSectionItem() {
        let track = TestFixtures.makeTrack(id: "convert-test", title: "Convert Track")
        let item = FavoriteItem.from(track)

        guard let homeSectionItem = item.asHomeSectionItem else {
            Issue.record("Expected non-nil HomeSectionItem")
            return
        }
        #expect(homeSectionItem.title == "Convert Track")
        if case let .track(convertedTrack) = homeSectionItem {
            #expect(convertedTrack.videoId == "convert-test")
        } else {
            Issue.record("Expected track type")
        }
    }
}
