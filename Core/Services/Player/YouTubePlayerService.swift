// YouTubePlayerService.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation
import Observation

/// Playback state and control for regular YouTube videos.
@MainActor
@Observable
final class YouTubePlayerService {
    // MARK: - State

    /// The video currently loaded for playback (nil when playback is closed).
    private(set) var currentVideo: YouTubeVideo?

    /// Whether the video is currently playing.
    private(set) var isPlaying = false

    /// Current position in seconds.
    private(set) var progress: Double = 0

    /// Video length in seconds.
    private(set) var duration: Double = 0

    /// Whether an ad is currently showing on the watch page.
    private(set) var isShowingAd = false

    /// Playback volume (0...1).
    var volume: Double = 1.0 {
        didSet {
            guard oldValue != self.volume else { return }
            YouTubeWatchWebView.shared.setVolume(self.volume)
        }
    }

    // MARK: - Hooks

    /// Called right before video playback starts.
    var playbackWillStart: (() -> Void)?

    /// Called when the current video finishes.
    var onVideoEnded: ((String?) -> Void)?

    // MARK: - Initialization

    init() {}

    // MARK: - Commands

    /// Starts playback of a video.
    func play(video: YouTubeVideo) {
        self.playbackWillStart?()
        self.currentVideo = video
        self.isPlaying = true
        self.progress = 0
        self.duration = 0
        YouTubeWatchWebView.shared.loadVideo(videoId: video.videoId)
    }

    /// Pauses playback.
    func pause() {
        self.isPlaying = false
        YouTubeWatchWebView.shared.pause()
    }

    /// Stops playback entirely and releases the WebView.
    func stop() {
        self.currentVideo = nil
        self.isPlaying = false
        self.progress = 0
        self.duration = 0
        self.isShowingAd = false
        YouTubeWatchWebView.shared.tearDown()
    }

    /// Prepares the player for switching to the music source.
    func prepareForSourceSwitch() {
        if self.isPlaying {
            self.pause()
        }
    }

    func seek(to time: Double) {
        self.progress = time
        YouTubeWatchWebView.shared.seek(to: time)
    }

    // MARK: - Bridge Callbacks

    struct PlaybackUpdate {
        let isPlaying: Bool
        let progress: Double
        let duration: Double
        var videoId: String?
        var title: String?
        var isAd = false
    }

    func updatePlaybackState(_ update: PlaybackUpdate) {
        // Ignore late bridge messages after stop() — the pause event fired by
        // tearDown() would otherwise resurrect currentVideo and re-open the
        // player UI, forcing a second Back click.
        guard self.currentVideo != nil else { return }
        if update.isPlaying, !self.isPlaying {
            self.playbackWillStart?()
        }
        self.isPlaying = update.isPlaying
        self.progress = update.progress
        self.duration = update.duration
        self.isShowingAd = update.isAd

        if let videoId = update.videoId, self.currentVideo?.videoId != videoId {
            self.currentVideo = YouTubeVideo(
                videoId: videoId,
                title: update.title ?? self.currentVideo?.title ?? "Unknown Video"
            )
            YouTubeWatchWebView.shared.currentVideoId = videoId
        }
    }

    func handleVideoEnded(videoId: String?) {
        self.isPlaying = false
        self.onVideoEnded?(videoId)
    }
}

// MARK: - YouTubeWatchPlaybackControlling Stub

/// Stub for WebView interface conformance.
@MainActor
protocol YouTubeWatchPlaybackControlling: AnyObject {
    func prepare(webKitManager: WebKitManager, playerService: YouTubePlayerService)
    func loadVideo(videoId: String)
    func reloadVideo(videoId: String, resumeAt seconds: Double?)
    func cancelPendingLoad()
    func playPause()
    func play()
    func pause()
    func seek(to time: Double)
    func setVolume(_ volume: Double)
    func showAirPlayPicker()
    func availableCaptionTracks() async -> [YouTubeCaptionTrack]
    func currentCaptionLanguageCode() async -> String?
    func setCaptionTrack(languageCode: String?)
    func availableQualityLevels() async -> [String]
    func currentQualityLevel() async -> String?
    func setQualityLevel(_ level: String)
    func storyboardSpec(expectedVideoId: String?) async -> String?
    func tearDown()
}
