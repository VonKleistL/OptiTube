import Foundation
import Testing
@testable import OptiTube

/// Tests for PlaybackStore.
@Suite("PlaybackStore", .serialized, .tags(.service))
@MainActor
struct PlaybackStoreTests {
    var playbackStore: PlaybackStore

    init() {
        self.playbackStore = Self.makePlaybackStore()
    }

    private static func makePlaybackStore() -> PlaybackStore {
        // Reset UserDefaults to ensure clean initial state for tests
        UserDefaults.standard.removeObject(forKey: "playerVolume")
        UserDefaults.standard.removeObject(forKey: "playerVolumeBeforeMute")
        UserDefaults.standard.removeObject(forKey: "playerShuffleEnabled")
        UserDefaults.standard.removeObject(forKey: "playerRepeatMode")
        UserDefaults.standard.removeObject(forKey: "optitube.saved.queue")
        UserDefaults.standard.removeObject(forKey: "optitube.saved.queueIndex")
        UserDefaults.standard.removeObject(forKey: "optitube.saved.playbackSession")
        SettingsManager.shared.rememberPlaybackSettings = false
        return PlaybackStore()
    }

    // MARK: - Initial State Tests

    @Test("Initial state is idle")
    func initialState() {
        #expect(self.playbackStore.state == .idle)
        #expect(self.playbackStore.currentTrack == nil)
        #expect(self.playbackStore.isPlaying == false)
        #expect(self.playbackStore.progress == 0)
        #expect(self.playbackStore.duration == 0)
        #expect(self.playbackStore.volume == 1.0)
    }

    @Test("isPlaying property")
    func isPlayingProperty() {
        #expect(self.playbackStore.isPlaying == false)
    }

    // MARK: - PlaybackState Tests

    @Test("PlaybackState equality")
    func playbackStateEquatable() {
        let state1 = PlaybackStore.PlaybackState.playing
        let state2 = PlaybackStore.PlaybackState.playing
        #expect(state1 == state2)

        let state3 = PlaybackStore.PlaybackState.paused
        #expect(state1 != state3)

        let error1 = PlaybackStore.PlaybackState.error("Test error")
        let error2 = PlaybackStore.PlaybackState.error("Test error")
        #expect(error1 == error2)

        let error3 = PlaybackStore.PlaybackState.error("Different error")
        #expect(error1 != error3)
    }

    @Test(
        "PlaybackState isPlaying returns correct value",
        arguments: [
            (PlaybackStore.PlaybackState.playing, true),
            (PlaybackStore.PlaybackState.paused, false),
            (PlaybackStore.PlaybackState.idle, false),
            (PlaybackStore.PlaybackState.loading, false),
            (PlaybackStore.PlaybackState.buffering, false),
            (PlaybackStore.PlaybackState.ended, false),
            (PlaybackStore.PlaybackState.error("test"), false),
        ]
    )
    func playbackStateIsPlaying(state: PlaybackStore.PlaybackState, expected: Bool) {
        #expect(state.isPlaying == expected)
    }

    // MARK: - Queue Tests

    @Test("Queue initially empty")
    func queueInitiallyEmpty() {
        #expect(self.playbackStore.queue.isEmpty)
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Update playback state to playing")
    func updatePlaybackState() {
        self.playbackStore.updatePlaybackState(isPlaying: true, progress: 30.0, duration: 180.0)

        #expect(self.playbackStore.state == .playing)
        #expect(self.playbackStore.progress == 30.0)
        #expect(self.playbackStore.duration == 180.0)
        #expect(self.playbackStore.isPlaying == true)
    }

    @Test("Update playback state to paused")
    func updatePlaybackStatePaused() {
        self.playbackStore.updatePlaybackState(isPlaying: true, progress: 30.0, duration: 180.0)
        #expect(self.playbackStore.state == .playing)

        self.playbackStore.updatePlaybackState(isPlaying: false, progress: 30.0, duration: 180.0)
        #expect(self.playbackStore.state == .paused)
        #expect(self.playbackStore.isPlaying == false)
    }

    @Test("Update track metadata")
    func updateTrackMetadata() {
        self.playbackStore.updateTrackMetadata(
            title: "Test Track",
            artist: "Test Artist",
            thumbnailUrl: "https://example.com/thumb.jpg",
            videoId: nil
        )

        #expect(self.playbackStore.currentTrack != nil)
        #expect(self.playbackStore.currentTrack?.title == "Test Track")
        #expect(self.playbackStore.currentTrack?.artistsDisplay == "Test Artist")
        #expect(self.playbackStore.currentTrack?.thumbnailURL?.absoluteString == "https://example.com/thumb.jpg")
    }

    @Test("Update track metadata with empty thumbnail")
    func updateTrackMetadataWithEmptyThumbnail() {
        self.playbackStore.updateTrackMetadata(
            title: "Test Track",
            artist: "Test Artist",
            thumbnailUrl: "",
            videoId: nil
        )

        #expect(self.playbackStore.currentTrack != nil)
        #expect(self.playbackStore.currentTrack?.title == "Test Track")
        #expect(self.playbackStore.currentTrack?.thumbnailURL == nil)
    }

    @Test("Confirm playback started")
    func confirmPlaybackStarted() {
        self.playbackStore.showMiniPlayer = true
        self.playbackStore.confirmPlaybackStarted()

        #expect(self.playbackStore.showMiniPlayer == false)
        #expect(self.playbackStore.state == .playing)
    }

    @Test("Mini player dismissed")
    func miniPlayerDismissed() {
        self.playbackStore.showMiniPlayer = true
        self.playbackStore.miniPlayerDismissed()

        #expect(self.playbackStore.showMiniPlayer == false)
    }

    // MARK: - Shuffle and Repeat Mode Tests

    @Test("Toggle shuffle")
    func toggleShuffle() {
        #expect(self.playbackStore.shuffleEnabled == false)

        self.playbackStore.toggleShuffle()
        #expect(self.playbackStore.shuffleEnabled == true)

        self.playbackStore.toggleShuffle()
        #expect(self.playbackStore.shuffleEnabled == false)
    }

    @Test("Cycle repeat mode")
    func cycleRepeatMode() {
        #expect(self.playbackStore.repeatMode == .off)

        self.playbackStore.cycleRepeatMode()
        #expect(self.playbackStore.repeatMode == .all)

        self.playbackStore.cycleRepeatMode()
        #expect(self.playbackStore.repeatMode == .one)

        self.playbackStore.cycleRepeatMode()
        #expect(self.playbackStore.repeatMode == .off)
    }

    // MARK: - Volume Tests

    @Test("Is muted initially false")
    func isMuted() {
        #expect(self.playbackStore.isMuted == false)
    }

    @Test("Initial volume is 1.0")
    func initialVolume() {
        #expect(self.playbackStore.volume == 1.0)
    }

    // MARK: - Queue Tests

    @Test("Play queue sets queue")
    func playQueueSetsQueue() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v3"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 0)

        #expect(self.playbackStore.queue.count == 3)
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Play queue starting at index")
    func playQueueStartingAtIndex() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v3"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 2)

        #expect(self.playbackStore.currentIndex == 2)
    }

    @Test("Play queue with invalid index clamps to valid range")
    func playQueueWithInvalidIndex() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 10)

        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Play empty queue does nothing")
    func playQueueEmptyDoesNothing() async {
        await self.playbackStore.playQueue([], startingAt: 0)
        #expect(self.playbackStore.queue.isEmpty)
    }

    // MARK: - User Interaction Tests

    @Test("hasUserInteractedThisSession initially false")
    func hasUserInteractedThisSessionInitiallyFalse() {
        #expect(self.playbackStore.hasUserInteractedThisSession == false)
    }

    @Test("confirmPlaybackStarted sets userInteracted")
    func confirmPlaybackStartedSetsUserInteracted() {
        #expect(self.playbackStore.hasUserInteractedThisSession == false)
        self.playbackStore.confirmPlaybackStarted()
        #expect(self.playbackStore.hasUserInteractedThisSession == true)
    }

    // MARK: - Pending Play Video Tests

    @Test("pendingPlayVideoId initially nil")
    func pendingPlayVideoIdInitiallyNil() {
        #expect(self.playbackStore.pendingPlayVideoId == nil)
    }

    // MARK: - Mini Player State Tests

    @Test("Mini player initially hidden")
    func miniPlayerInitiallyHidden() {
        #expect(self.playbackStore.showMiniPlayer == false)
    }

    // MARK: - Queue/Lyrics Mutual Exclusivity Tests

    @Test("showQueue initially false")
    func showQueueInitiallyFalse() {
        #expect(self.playbackStore.showQueue == false)
    }

    @Test("showLyrics initially false")
    func showLyricsInitiallyFalse() {
        #expect(self.playbackStore.showLyrics == false)
    }

    @Test("Show queue closes lyrics")
    func showQueueClosesLyrics() {
        self.playbackStore.showLyrics = true
        #expect(self.playbackStore.showLyrics == true)
        #expect(self.playbackStore.showQueue == false)

        self.playbackStore.showQueue = true
        #expect(self.playbackStore.showQueue == true)
        #expect(self.playbackStore.showLyrics == false, "Opening queue should close lyrics")
    }

    @Test("Show lyrics closes queue")
    func showLyricsClosesQueue() {
        self.playbackStore.showQueue = true
        #expect(self.playbackStore.showQueue == true)
        #expect(self.playbackStore.showLyrics == false)

        self.playbackStore.showLyrics = true
        #expect(self.playbackStore.showLyrics == true)
        #expect(self.playbackStore.showQueue == false, "Opening lyrics should close queue")
    }

    @Test("Both sidebars can be closed")
    func bothSidebarsCanBeClosed() {
        self.playbackStore.showQueue = true
        #expect(self.playbackStore.showQueue == true)

        self.playbackStore.showQueue = false
        #expect(self.playbackStore.showQueue == false)
        #expect(self.playbackStore.showLyrics == false)
    }

    // MARK: - Clear Queue Tests

    @Test("Clear queue with no current track")
    func clearQueueWithNoCurrentTrack() {
        self.playbackStore.clearQueue()

        #expect(self.playbackStore.queue.isEmpty)
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Clear queue keeps current track")
    func clearQueueKeepsCurrentTrack() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v3"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 1)

        self.playbackStore.clearQueue()

        #expect(self.playbackStore.queue.count == 1)
        #expect(self.playbackStore.queue.first?.videoId == "v2")
        #expect(self.playbackStore.currentIndex == 0)
    }

    // MARK: - Next with Shuffle Tests

    @Test("Next with shuffle picks random track from queue")
    func nextWithShufflePicksFromQueue() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v3"),
            Track(id: "4", title: "Track 4", artists: [], album: nil, duration: 240, thumbnailURL: nil, videoId: "v4"),
            Track(id: "5", title: "Track 5", artists: [], album: nil, duration: 260, thumbnailURL: nil, videoId: "v5"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 0)
        self.playbackStore.toggleShuffle()
        #expect(self.playbackStore.shuffleEnabled == true)

        // Call next multiple times and verify we always pick from the queue
        let validVideoIds = Set(tracks.map(\.videoId))
        for _ in 0 ..< 10 {
            await self.playbackStore.next()
            // Verify the current track is from our queue
            #expect(validVideoIds.contains(self.playbackStore.currentTrack?.videoId ?? ""), "Shuffle should only pick tracks from the queue")
        }
    }

    @Test("UpdateTrackMetadata corrects YouTube autoplay with OptiTube-initiated playback")
    func updateTrackMetadataCorrectsYouTubeAutoplay() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v3"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 0)
        self.playbackStore.toggleShuffle()

        // Simulate calling next which sets isOptiTubeInitiatedPlayback
        await self.playbackStore.next()

        // Simulate YouTube loading a DIFFERENT track (not from our queue)
        // This should trigger a re-play of the intended track
        self.playbackStore.updateTrackMetadata(
            title: "YouTube Autoplay Track",
            artist: "Random Artist",
            thumbnailUrl: "",
            videoId: nil
        )

        // Give async correction task time to run
        try? await Task.sleep(for: .milliseconds(100))

        // The current track should still be the intended track from our queue
        // (or a re-played version of it)
        let validVideoIds = Set(tracks.map(\.videoId))
        #expect(validVideoIds.contains(self.playbackStore.currentTrack?.videoId ?? ""), "Track should be from our queue, not YouTube autoplay")
    }

    // MARK: - Play From Queue Tests

    @Test("Play from queue valid index")
    func playFromQueueValidIndex() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v3"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 0)
        await self.playbackStore.playFromQueue(at: 2)

        #expect(self.playbackStore.currentIndex == 2)
        #expect(self.playbackStore.currentTrack?.videoId == "v3")
    }

    @Test("Play from queue invalid index does nothing")
    func playFromQueueInvalidIndexDoesNothing() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 0)
        await self.playbackStore.playFromQueue(at: 5)

        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Play from queue negative index does nothing")
    func playFromQueueNegativeIndexDoesNothing() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
        ]

        await playbackStore.playQueue(tracks, startingAt: 0)
        await self.playbackStore.playFromQueue(at: -1)

        #expect(self.playbackStore.currentIndex == 0)
    }

    // MARK: - Play With Radio Tests

    @Test("Play with radio starts playback immediately")
    func playWithRadioStartsPlaybackImmediately() async {
        let track = Track(
            id: "radio-seed",
            title: "Seed Track",
            artists: [Artist(id: "artist-1", name: "Artist 1")],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "radio-seed-video"
        )

        await playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.currentTrack?.videoId == "radio-seed-video")
        #expect(self.playbackStore.currentTrack?.title == "Seed Track")
        #expect(self.playbackStore.queue.isEmpty == false)
    }

    @Test("Play with radio sets queue with seed track")
    func playWithRadioSetsQueueWithSeedTrack() async {
        let track = Track(
            id: "seed",
            title: "Seed Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "seed-video"
        )

        await playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.queue.count == 1)
        #expect(self.playbackStore.queue.first?.videoId == "seed-video")
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Play with radio fetches radio queue")
    func playWithRadioFetchesRadioQueue() async {
        let mockClient = MockYTMusicClient()
        let radioTracks = [
            Track(id: "radio-1", title: "Radio Track 1", artists: [], videoId: "radio-video-1"),
            Track(id: "radio-2", title: "Radio Track 2", artists: [], videoId: "radio-video-2"),
            Track(id: "radio-3", title: "Radio Track 3", artists: [], videoId: "radio-video-3"),
        ]
        mockClient.radioQueueTracks["seed-video"] = radioTracks
        self.playbackStore.setYTMusicClient(mockClient)

        let track = Track(
            id: "seed",
            title: "Seed Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "seed-video"
        )

        await playbackStore.playWithRadio(track: track)

        #expect(mockClient.getRadioQueueCalled == true)
        #expect(mockClient.getRadioQueueVideoIds.first == "seed-video")
        #expect(self.playbackStore.queue.count == 4)
        #expect(self.playbackStore.queue.first?.videoId == "seed-video", "Seed track should be at front of queue")
        #expect(self.playbackStore.currentIndex == 0)
    }

    @Test("Play with radio keeps seed track at front when not in radio")
    func playWithRadioKeepsSeedTrackAtFrontWhenNotInRadio() async {
        let mockClient = MockYTMusicClient()
        let radioTracks = [
            Track(id: "radio-1", title: "Radio Track 1", artists: [], videoId: "radio-video-1"),
            Track(id: "radio-2", title: "Radio Track 2", artists: [], videoId: "radio-video-2"),
        ]
        mockClient.radioQueueTracks["seed-video"] = radioTracks
        self.playbackStore.setYTMusicClient(mockClient)

        let track = Track(
            id: "seed",
            title: "Seed Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "seed-video"
        )

        await playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.queue.count == 3)
        #expect(self.playbackStore.queue[0].videoId == "seed-video", "Seed track should be first")
        #expect(self.playbackStore.queue[1].videoId == "radio-video-1")
        #expect(self.playbackStore.queue[2].videoId == "radio-video-2")
    }

    @Test("Play with radio reorders seed track to front")
    func playWithRadioReordersSeedTrackToFront() async {
        let mockClient = MockYTMusicClient()
        let radioTracks = [
            Track(id: "radio-1", title: "Radio Track 1", artists: [], videoId: "radio-video-1"),
            Track(id: "seed", title: "Seed Track", artists: [], videoId: "seed-video"),
            Track(id: "radio-2", title: "Radio Track 2", artists: [], videoId: "radio-video-2"),
        ]
        mockClient.radioQueueTracks["seed-video"] = radioTracks
        self.playbackStore.setYTMusicClient(mockClient)

        let track = Track(
            id: "seed",
            title: "Seed Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "seed-video"
        )

        await playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.queue.count == 3)
        #expect(self.playbackStore.queue[0].videoId == "seed-video", "Seed track should be first")
        #expect(self.playbackStore.queue[1].videoId == "radio-video-1")
        #expect(self.playbackStore.queue[2].videoId == "radio-video-2")
    }

    @Test("Play with radio handles empty radio queue")
    func playWithRadioHandlesEmptyRadioQueue() async {
        let mockClient = MockYTMusicClient()
        self.playbackStore.setYTMusicClient(mockClient)

        let track = Track(
            id: "lonely",
            title: "Lonely Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "lonely-video"
        )

        await playbackStore.playWithRadio(track: track)

        #expect(self.playbackStore.queue.count == 1)
        #expect(self.playbackStore.queue.first?.videoId == "lonely-video")
    }

    @Test("Radio queue replacement records undo and redo history")
    func radioQueueReplacementRecordsUndoRedo() async {
        let mockClient = MockYTMusicClient()
        mockClient.radioQueueTracks["seed-video"] = [
            Track(id: "radio-1", title: "Radio Track 1", artists: [], videoId: "radio-video-1"),
            Track(id: "radio-2", title: "Radio Track 2", artists: [], videoId: "radio-video-2"),
        ]
        self.playbackStore.setYTMusicClient(mockClient)

        let seedTrack = Track(
            id: "seed",
            title: "Seed Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "seed-video"
        )

        await self.playbackStore.playWithRadio(track: seedTrack)

        #expect(self.playbackStore.queue.count == 3)

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.count == 1)
        #expect(self.playbackStore.queue.first?.videoId == "seed-video")

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.count == 3)
        #expect(self.playbackStore.queue.last?.videoId == "radio-video-2")
    }

    // MARK: - Queue Persistence and Undo/Redo Tests

    @Test("Queue persistence restores queue, index, and seek position")
    func queuePersistenceRestoresSession() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], album: nil, duration: 180, thumbnailURL: nil, videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], album: nil, duration: 220, thumbnailURL: nil, videoId: "v2"),
            Track(id: "3", title: "Track 3", artists: [], album: nil, duration: 200, thumbnailURL: nil, videoId: "v3"),
        ]

        await self.playbackStore.playQueue(tracks, startingAt: 1)
        self.playbackStore.updatePlaybackState(isPlaying: false, progress: 42, duration: 220)
        self.playbackStore.saveQueueForPersistence()

        let restoredStore = PlaybackStore()
        let restored = restoredStore.restoreQueueFromPersistence()

        #expect(restored)
        #expect(restoredStore.queue.count == 3)
        #expect(restoredStore.currentIndex == 1)
        #expect(restoredStore.currentTrack?.videoId == "v2")
        #expect(restoredStore.pendingRestoredSeek == 42)
        #expect(restoredStore.isPendingRestoredLoadDeferred == true)

        restoredStore.clearSavedQueue()
    }

    @Test("Append queue mutation records undo and redo history")
    func queueAppendRecordsUndoRedo() async {
        let track1 = Track(id: "1", title: "Track 1", artists: [], videoId: "v1")
        let track2 = Track(id: "2", title: "Track 2", artists: [], videoId: "v2")
        let track3 = Track(id: "3", title: "Track 3", artists: [], videoId: "v3")

        await self.playbackStore.playQueue([track1, track2], startingAt: 0)
        self.playbackStore.appendToQueue([track3])

        #expect(self.playbackStore.queue.count == 3)
        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.count == 2)
        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.count == 3)
    }

    @Test("Mix continuation append records undo and redo history")
    func mixContinuationAppendRecordsUndoRedo() async {
        let mockClient = MockYTMusicClient()
        mockClient.mixQueueContinuationResults["mix-token-1"] = RadioQueueResult(
            tracks: [
                Track(id: "3", title: "Track 3", artists: [], videoId: "v3"),
                Track(id: "4", title: "Track 4", artists: [], videoId: "v4"),
            ],
            continuationToken: nil
        )
        self.playbackStore.setYTMusicClient(mockClient)

        let baseTracks = [
            Track(id: "1", title: "Track 1", artists: [], videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], videoId: "v2"),
        ]
        await self.playbackStore.playQueue(baseTracks, startingAt: 0)
        self.playbackStore.mixContinuationToken = "mix-token-1"

        await self.playbackStore.fetchMoreMixTracksIfNeeded()

        #expect(mockClient.getMixQueueContinuationCalled)
        #expect(self.playbackStore.queue.map(\.videoId) == ["v1", "v2", "v3", "v4"])

        self.playbackStore.undoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["v1", "v2"])

        self.playbackStore.redoQueue()
        #expect(self.playbackStore.queue.map(\.videoId) == ["v1", "v2", "v3", "v4"])
    }

    @Test("Clear saved queue removes persisted playback session")
    func clearSavedQueueRemovesPersistence() async {
        let tracks = [
            Track(id: "1", title: "Track 1", artists: [], videoId: "v1"),
            Track(id: "2", title: "Track 2", artists: [], videoId: "v2"),
        ]

        await self.playbackStore.playQueue(tracks, startingAt: 0)
        self.playbackStore.saveQueueForPersistence()
        self.playbackStore.clearSavedQueue()

        let restoredStore = PlaybackStore()
        #expect(restoredStore.restoreQueueFromPersistence() == false)
    }

    @Test("Queue metadata enrichment fills incomplete queue entries")
    func queueMetadataEnrichmentFillsIncompleteEntries() async {
        let mockClient = MockYTMusicClient()
        let enrichedTrack = Track(
            id: "v1",
            title: "Enriched Track",
            artists: [Artist(id: "artist-1", name: "Enriched Artist")],
            album: nil,
            duration: 210,
            thumbnailURL: URL(string: "https://example.com/cover.jpg"),
            videoId: "v1"
        )
        mockClient.trackMetadataByVideoId["v1"] = enrichedTrack
        self.playbackStore.setYTMusicClient(mockClient)

        let incompleteTrack = Track(
            id: "v1",
            title: "Loading...",
            artists: [],
            album: nil,
            duration: nil,
            thumbnailURL: nil,
            videoId: "v1"
        )

        await self.playbackStore.playQueue([incompleteTrack], startingAt: 0)
        #expect(self.playbackStore.identifyTracksNeedingEnrichment().count == 1)

        await self.playbackStore.enrichQueueMetadata()

        #expect(self.playbackStore.queue.first?.title == "Enriched Track")
        #expect(self.playbackStore.queue.first?.artistsDisplay == "Enriched Artist")
        #expect(self.playbackStore.queue.first?.thumbnailURL?.absoluteString == "https://example.com/cover.jpg")
        #expect(self.playbackStore.identifyTracksNeedingEnrichment().isEmpty)
    }

    @Test("Observed video ID reconciliation updates native queue index")
    func observedVideoIdReconciliationUpdatesQueueIndex() async {
        let playbackStore = Self.makePlaybackStore()
        let first = Track(
            id: "1",
            title: "Track 1",
            artists: [Artist(id: "artist-1", name: "Artist 1")],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "v1"
        )
        let second = Track(
            id: "2",
            title: "Track 2",
            artists: [Artist(id: "artist-2", name: "Artist 2")],
            album: nil,
            duration: 200,
            thumbnailURL: nil,
            videoId: "v2"
        )

        await playbackStore.playQueue([first, second], startingAt: 0)

        playbackStore.updateTrackMetadata(
            title: second.title,
            artist: second.artistsDisplay,
            thumbnailUrl: "",
            videoId: second.videoId
        )

        #expect(playbackStore.currentIndex == 1)
        #expect(playbackStore.currentTrack?.videoId == "v2")
    }

    @Test("Repeat-one reconciliation ignores observed track drift")
    func repeatOneReconciliationIgnoresObservedTrackDrift() async {
        let playbackStore = Self.makePlaybackStore()
        let first = Track(id: "1", title: "Track 1", artists: [Artist(id: "artist-1", name: "Artist 1")], videoId: "v1")
        let second = Track(id: "2", title: "Track 2", artists: [Artist(id: "artist-2", name: "Artist 2")], videoId: "v2")

        playbackStore.confirmPlaybackStarted()
        await playbackStore.playQueue([first, second], startingAt: 0)
        playbackStore.cycleRepeatMode()
        playbackStore.cycleRepeatMode()

        playbackStore.updateTrackMetadata(
            title: second.title,
            artist: second.artistsDisplay,
            thumbnailUrl: "",
            videoId: second.videoId
        )

        await Task.yield()
        await Task.yield()

        #expect(playbackStore.repeatMode == .one)
        #expect(playbackStore.currentIndex == 0)
        #expect(playbackStore.currentTrack?.videoId == "v1")
    }

    @Test("Track-ended stale observed video ID is ignored")
    func trackEndedStaleObservedVideoIdIsIgnored() async {
        let playbackStore = Self.makePlaybackStore()
        let first = Track(id: "1", title: "Track 1", artists: [], videoId: "v1")
        let second = Track(id: "2", title: "Track 2", artists: [], videoId: "v2")

        await playbackStore.playQueue([first, second], startingAt: 0)
        await playbackStore.handleTrackEnded(observedVideoId: "v2")

        #expect(playbackStore.currentIndex == 0)
        #expect(playbackStore.currentTrack?.videoId == "v1")
    }
}
