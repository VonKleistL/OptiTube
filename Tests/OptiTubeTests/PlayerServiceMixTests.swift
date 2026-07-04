import Foundation
import Testing
@testable import OptiTube

/// Tests for PlaybackStore+Queue mix functionality.
@Suite("PlaybackStore+Mix", .serialized, .tags(.service))
@MainActor
struct PlaybackStoreMixTests {
    var playbackStore: PlaybackStore
    var mockClient: MockYTMusicClient

    init() {
        UserDefaults.standard.removeObject(forKey: "playerShuffleEnabled")
        UserDefaults.standard.removeObject(forKey: "playerRepeatMode")
        SettingsManager.shared.rememberPlaybackSettings = false
        self.mockClient = MockYTMusicClient()
        self.playbackStore = PlaybackStore()
        self.playbackStore.setYTMusicClient(self.mockClient)
        // Enable hasUserInteractedThisSession to avoid mini player popup
        self.playbackStore.confirmPlaybackStarted()
    }

    // MARK: - playWithMix Tests

    @Test("playWithMix does nothing without client")
    func playWithMixNoClient() async {
        let service = PlaybackStore()
        // No client set

        await service.playWithMix(playlistId: "RDEM123", startVideoId: nil)

        #expect(service.queue.isEmpty)
    }

    @Test("playWithMix handles empty mix queue")
    func playWithMixEmptyQueue() async {
        // MockYTMusicClient returns empty by default

        await self.playbackStore.playWithMix(playlistId: "RDEM123", startVideoId: nil)

        #expect(self.playbackStore.queue.isEmpty)
    }

    // MARK: - fetchMoreMixTracksIfNeeded Tests

    @Test("fetchMoreMixTracksIfNeeded does nothing without continuation token")
    func fetchMoreMixTracksNoToken() async {
        self.playbackStore.mixContinuationToken = nil
        let tracks = TestFixtures.makeTracks(count: 5)
        await self.playbackStore.playQueue(tracks, startingAt: 4)

        await self.playbackStore.fetchMoreMixTracksIfNeeded()

        #expect(self.playbackStore.queue.count == 5)
    }

    @Test("fetchMoreMixTracksIfNeeded does nothing when not near end")
    func fetchMoreMixTracksNotNearEnd() async {
        self.playbackStore.mixContinuationToken = "some-token"
        let tracks = TestFixtures.makeTracks(count: 20)
        await self.playbackStore.playQueue(tracks, startingAt: 0)

        await self.playbackStore.fetchMoreMixTracksIfNeeded()

        // No change expected since we're at the beginning
        #expect(self.playbackStore.queue.count == 20)
    }

    // MARK: - Queue Management Tests

    @Test("clearQueue clears mixContinuationToken")
    func clearQueueClearsContinuationToken() async {
        self.playbackStore.mixContinuationToken = "some-token"
        let tracks = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(tracks, startingAt: 1)

        self.playbackStore.clearQueue()

        #expect(self.playbackStore.mixContinuationToken == nil)
    }

    @Test("clearQueue records undo and redo history")
    func clearQueueRecordsUndoRedo() async {
        let tracks = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(tracks, startingAt: 1)

        self.playbackStore.clearQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-1"])

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-0", "video-1", "video-2"])
        #expect(self.playbackStore.currentIndex == 1)

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-1"])
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("clearQueueEntirely records undo and redo history")
    func clearQueueEntirelyRecordsUndoRedo() async {
        let tracks = TestFixtures.makeTracks(count: 2)
        await self.playbackStore.playQueue(tracks, startingAt: 0)

        self.playbackStore.clearQueueEntirely()
        #expect(self.playbackStore.queue.isEmpty)

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-0", "video-1"])

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.isEmpty)
    }

    @Test("playQueue clears mixContinuationToken")
    func playQueueClearsContinuationToken() async {
        self.playbackStore.mixContinuationToken = "some-token"
        let tracks = TestFixtures.makeTracks(count: 3)

        await self.playbackStore.playQueue(tracks, startingAt: 0)

        #expect(self.playbackStore.mixContinuationToken == nil)
    }

    // MARK: - playWithRadio Tests

    @Test("playWithRadio clears mixContinuationToken")
    func playWithRadioClearsContinuationToken() async {
        self.playbackStore.mixContinuationToken = "some-token"
        let track = TestFixtures.makeTrack(id: "radio-seed")

        await self.playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.mixContinuationToken == nil)
    }

    @Test("playWithRadio sets initial queue with seed track")
    func playWithRadioSetsInitialQueue() async {
        let track = TestFixtures.makeTrack(id: "radio-seed", title: "Seed Track")

        await self.playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.queue.count >= 1)
        #expect(self.playbackStore.queue.first?.videoId == "radio-seed")
        #expect(self.playbackStore.currentIndex == 0)
    }

    // MARK: - insertNextInQueue Tests

    @Test("insertNextInQueue inserts tracks after current track")
    func insertNextInQueue() async {
        let queue = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        let newTracks = [
            TestFixtures.makeTrack(id: "new-1", title: "New Track 1"),
            TestFixtures.makeTrack(id: "new-2", title: "New Track 2"),
        ]

        self.playbackStore.insertNextInQueue(newTracks)

        #expect(self.playbackStore.queue.count == 5)
        #expect(self.playbackStore.queue[1].videoId == "new-1")
        #expect(self.playbackStore.queue[2].videoId == "new-2")
    }

    @Test("insertNextInQueue records undo and redo history")
    func insertNextInQueueRecordsUndoRedo() async {
        let queue = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        self.playbackStore.insertNextInQueue([
            TestFixtures.makeTrack(id: "new-1"),
            TestFixtures.makeTrack(id: "new-2"),
        ])
        let insertedOrder = self.playbackStore.queue.map(\.videoId)

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-0", "video-1", "video-2"])

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == insertedOrder)
    }

    @Test("insertNextInQueue with empty array does nothing")
    func insertNextInQueueEmpty() async {
        let queue = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        self.playbackStore.insertNextInQueue([])

        #expect(self.playbackStore.queue.count == 3)
    }

    // MARK: - appendToQueue Tests

    @Test("appendToQueue adds tracks to end")
    func appendToQueue() async {
        let queue = TestFixtures.makeTracks(count: 2)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        let newTracks = [
            TestFixtures.makeTrack(id: "appended-1"),
            TestFixtures.makeTrack(id: "appended-2"),
        ]

        self.playbackStore.appendToQueue(newTracks)

        #expect(self.playbackStore.queue.count == 4)
        #expect(self.playbackStore.queue.last?.videoId == "appended-2")
    }

    @Test("appendToQueue with empty array does nothing")
    func appendToQueueEmpty() async {
        let queue = TestFixtures.makeTracks(count: 2)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        self.playbackStore.appendToQueue([])

        #expect(self.playbackStore.queue.count == 2)
    }

    // MARK: - removeFromQueue Tests

    @Test("removeFromQueue removes tracks by video ID")
    func removeFromQueue() async {
        let queue = TestFixtures.makeTracks(count: 5)
        await self.playbackStore.playQueue(queue, startingAt: 2)

        self.playbackStore.removeFromQueue(videoIds: Set(["video-0", "video-4"]))

        #expect(self.playbackStore.queue.count == 3)
        #expect(!self.playbackStore.queue.contains { $0.videoId == "video-0" })
        #expect(!self.playbackStore.queue.contains { $0.videoId == "video-4" })
    }

    @Test("removeFromQueue adjusts currentIndex when needed")
    func removeFromQueueAdjustsIndex() async {
        let queue = TestFixtures.makeTracks(count: 5)
        await self.playbackStore.playQueue(queue, startingAt: 2)

        // Remove tracks before current index
        self.playbackStore.removeFromQueue(videoIds: Set(["video-0", "video-1"]))

        // Current track should now be at index 0
        #expect(self.playbackStore.queue.count == 3)
        #expect(self.playbackStore.currentTrack?.videoId == "video-2")
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("removeFromQueue records undo and redo history")
    func removeFromQueueRecordsUndoRedo() async {
        let queue = TestFixtures.makeTracks(count: 4)
        await self.playbackStore.playQueue(queue, startingAt: 1)

        self.playbackStore.removeFromQueue(videoIds: Set(["video-0", "video-3"]))
        let reducedOrder = self.playbackStore.queue.map(\.videoId)

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-0", "video-1", "video-2", "video-3"])
        #expect(self.playbackStore.currentIndex == 1)

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == reducedOrder)
        #expect(self.playbackStore.currentIndex == 0)
    }

    // MARK: - reorderQueue Tests

    @Test("reorderQueue changes order based on video IDs")
    func reorderQueue() async {
        let queue = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        self.playbackStore.reorderQueue(videoIds: ["video-2", "video-0", "video-1"])

        #expect(self.playbackStore.queue.count == 3)
        #expect(self.playbackStore.queue[0].videoId == "video-2")
        #expect(self.playbackStore.queue[1].videoId == "video-0")
        #expect(self.playbackStore.queue[2].videoId == "video-1")
    }

    @Test("reorderQueue updates currentIndex to match current track")
    func reorderQueueUpdatesIndex() async {
        let queue = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        // Current track is video-0 at index 0
        self.playbackStore.reorderQueue(videoIds: ["video-2", "video-1", "video-0"])

        // Current track should now be at index 2
        #expect(self.playbackStore.currentTrack?.videoId == "video-0")
        #expect(self.playbackStore.currentIndex == 2)
    }

    @Test("reorderQueue records undo and redo history")
    func reorderQueueRecordsUndoRedo() async {
        let queue = TestFixtures.makeTracks(count: 3)
        await self.playbackStore.playQueue(queue, startingAt: 0)

        self.playbackStore.reorderQueue(videoIds: ["video-2", "video-0", "video-1"])
        let reordered = self.playbackStore.queue.map(\.videoId)

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-0", "video-1", "video-2"])
        #expect(self.playbackStore.currentIndex == 0)

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == reordered)
        #expect(self.playbackStore.currentIndex == 1)
    }

    // MARK: - shuffleQueue Tests

    @Test("shuffleQueue keeps current track at front")
    func shuffleQueueKeepsCurrentAtFront() async {
        let queue = TestFixtures.makeTracks(count: 10)
        await self.playbackStore.playQueue(queue, startingAt: 5)

        self.playbackStore.shuffleQueue()

        #expect(self.playbackStore.queue.count == 10)
        #expect(self.playbackStore.queue[0].videoId == "video-5")
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("shuffleQueue does nothing with single track")
    func shuffleQueueSingleTrack() async {
        let queue = [TestFixtures.makeTrack(id: "only-one")]
        await self.playbackStore.playQueue(queue, startingAt: 0)

        self.playbackStore.shuffleQueue()

        #expect(self.playbackStore.queue.count == 1)
        #expect(self.playbackStore.queue[0].videoId == "only-one")
    }

    @Test("shuffleQueue records undo and redo history")
    func shuffleQueueRecordsUndoRedo() async {
        let queue = TestFixtures.makeTracks(count: 6)
        await self.playbackStore.playQueue(queue, startingAt: 2)

        self.playbackStore.shuffleQueue()
        let shuffledOrder = self.playbackStore.queue.map(\.videoId)

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["video-0", "video-1", "video-2", "video-3", "video-4", "video-5"])
        #expect(self.playbackStore.currentIndex == 2)

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == shuffledOrder)
        #expect(self.playbackStore.currentIndex == 0)
    }
}
