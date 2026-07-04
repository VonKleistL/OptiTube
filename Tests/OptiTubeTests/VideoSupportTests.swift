import Foundation
import Testing
@testable import OptiTube

/// Tests for Video Support functionality.
@Suite("Video Support", .serialized, .tags(.service))
@MainActor
struct VideoSupportTests {
    var playbackStore: PlaybackStore

    init() {
        UserDefaults.standard.removeObject(forKey: "playerVolume")
        UserDefaults.standard.removeObject(forKey: "playerVolumeBeforeMute")
        self.playbackStore = PlaybackStore()
    }

    // MARK: - Initial State Tests

    @Test("currentTrackHasVideo initially false")
    func currentTrackHasVideoInitiallyFalse() {
        #expect(self.playbackStore.currentTrackHasVideo == false)
    }

    @Test("showVideo initially false")
    func showVideoInitiallyFalse() {
        #expect(self.playbackStore.showVideo == false)
    }

    // MARK: - Video Availability Tests

    @Test("updateVideoAvailability sets hasVideo correctly")
    func updateVideoAvailabilitySetsHasVideo() {
        #expect(self.playbackStore.currentTrackHasVideo == false)

        self.playbackStore.updateVideoAvailability(hasVideo: true)
        #expect(self.playbackStore.currentTrackHasVideo == true)

        self.playbackStore.updateVideoAvailability(hasVideo: false)
        #expect(self.playbackStore.currentTrackHasVideo == false)
    }

    // MARK: - Video Window Behavior Tests

    @Test("showVideo stays open even when hasVideo becomes false")
    func showVideoStaysOpenWhenHasVideoChanges() {
        // The video window should not auto-close based on hasVideo detection
        // because detection is unreliable when video mode CSS is active.
        // Only trackChanged should close the video window.
        self.playbackStore.updateVideoAvailability(hasVideo: true)
        self.playbackStore.showVideo = true
        #expect(self.playbackStore.showVideo == true)

        // hasVideo becomes false (unreliable detection during video mode)
        self.playbackStore.updateVideoAvailability(hasVideo: false)
        #expect(self.playbackStore.showVideo == true, "Video window should NOT auto-close based on hasVideo")
    }

    @Test("showVideo can be enabled even when hasVideo is false")
    func showVideoCanBeEnabledWhenNoVideo() {
        // We allow enabling showVideo even without hasVideo because:
        // 1. hasVideo detection might lag behind
        // 2. User explicitly requested video mode
        #expect(self.playbackStore.currentTrackHasVideo == false)
        self.playbackStore.showVideo = true
        #expect(self.playbackStore.showVideo == true, "showVideo should be allowed even if hasVideo is false")
    }

    @Test("showVideo stays open when changing to another video track")
    func showVideoStaysOpenForVideoTrack() {
        // Enable video with a video-capable track
        self.playbackStore.updateVideoAvailability(hasVideo: true)
        self.playbackStore.showVideo = true
        #expect(self.playbackStore.showVideo == true)

        // Track changes but still has video
        self.playbackStore.updateVideoAvailability(hasVideo: true)
        #expect(self.playbackStore.showVideo == true, "Video window should stay open")
    }

    // MARK: - Model Tests

    @Test("Track.hasVideo property exists and defaults to nil")
    func trackHasVideoPropertyExists() {
        let track = Track(
            id: "test",
            title: "Test Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "test-video"
        )
        #expect(track.hasVideo == nil)
    }

    @Test("Track.hasVideo can be set explicitly")
    func trackHasVideoCanBeSet() {
        let trackWithVideo = Track(
            id: "test",
            title: "Test Track",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "test-video",
            hasVideo: true
        )
        #expect(trackWithVideo.hasVideo == true)

        let trackWithoutVideo = Track(
            id: "test2",
            title: "Test Track 2",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "test-video-2",
            hasVideo: false
        )
        #expect(trackWithoutVideo.hasVideo == false)
    }

    // MARK: - Display Mode Tests

    @Test("SingletonPlayerWebView DisplayMode enum has all cases")
    func displayModeEnumHasAllCases() {
        let hidden = SingletonPlayerWebView.DisplayMode.hidden
        let miniPlayer = SingletonPlayerWebView.DisplayMode.miniPlayer
        let video = SingletonPlayerWebView.DisplayMode.video

        // Just verify the enum cases exist
        #expect(hidden == .hidden)
        #expect(miniPlayer == .miniPlayer)
        #expect(video == .video)
    }
}
