import Foundation
import Observation
import os

// MARK: - PlaybackStore

/// Controls music playback via a hidden WKWebView.
@MainActor
@Observable
final class PlaybackStore: NSObject, PlaybackStoreProtocol {
    /// Shared instance for AppleScript access.
    static var shared: PlaybackStore?
    /// Current playback state.
    enum PlaybackState: Equatable, Sendable {
        case idle
        case loading
        case playing
        case paused
        case buffering
        case ended
        case error(String)

        var isPlaying: Bool {
            self == .playing
        }
    }

    /// Repeat mode for playback.
    enum RepeatMode: Sendable {
        case off
        case all
        case one
    }

    /// Available visualizer styles.
    enum VisualizerType: String, CaseIterable, Identifiable {
        case none = "None"
        case particles = "Particles"
        
        var id: String { rawValue }
    }

    // MARK: - Observable State

    /// Current playback state.
    private(set) var state: PlaybackState = .idle

    /// Callback invoked when playback is about to start.
    var playbackWillStart: (() -> Void)?

    /// Currently playing track.
    var currentTrack: Track? {
        didSet {
            // Update color palette when track changes
            Task {
                await updateColorPalette()
                syncWithWidget()
            }
        }
    }

    /// Current color palette extracted from album art.
    var currentArtworkPalette: ColorExtractor.ColorPalette = .default

    /// Whether playback is active.
    var isPlaying: Bool { self.state.isPlaying }

    /// Current playback position in seconds.
    private(set) var progress: TimeInterval = 0

    /// High-resolution playback time in milliseconds for synced lyrics.
    var currentTimeMs: Int = 0

    /// Total duration of current track in seconds.
    private(set) var duration: TimeInterval = 0

    /// Current volume (0.0 - 1.0).
    private(set) var volume: Double = 1.0

    /// Volume before muting, for unmute restoration.
    private var volumeBeforeMute: Double = 1.0

    /// Whether audio is currently muted.
    var isMuted: Bool { self.volume == 0 }

    /// Whether shuffle mode is enabled.
    private(set) var shuffleEnabled: Bool = false

    /// Current repeat mode.
    private(set) var repeatMode: RepeatMode = .off

    /// Current active visualizer style.
    var activeVisualizer: VisualizerType = .none

    /// Mock frequency data for visualization (0.0 to 1.0).
    /// In a real implementation, this would be fed by an Audio Engine or WKWebView bridge.
    private(set) var audioLevels: [CGFloat] = Array(repeating: 0.0, count: 8)

    /// Playback queue.
    var queue: [Track] = []

    /// Index of current track in queue.
    var currentIndex: Int = 0

    /// Whether the mini player should be shown (user needs to interact to start playback).
    var showMiniPlayer: Bool = false

    /// The video ID that needs to be played in the mini player.
    private(set) var pendingPlayVideoId: String?

    /// Whether the user has successfully interacted at least once this session.
    /// After first successful playback, we can auto-play without showing the popup.
    private(set) var hasUserInteractedThisSession: Bool = false

    /// Saved seek position to apply once a restored session finishes loading.
    var pendingRestoredSeek: TimeInterval?

    /// Whether a restored session is waiting for explicit user-triggered load.
    var isPendingRestoredLoadDeferred: Bool = false

    /// Whether launch-time session restoration is still reconciling with the player observer.
    var isRestoringPlaybackSession: Bool = false

    /// Whether a restored load should resume automatically after seeking.
    var shouldAutoResumeAfterRestoredLoad: Bool = false

    /// Like status of the current track.
    var currentTrackLikeStatus: LikeStatus = .indifferent

    /// Whether the current track is in the user's library.
    var currentTrackInLibrary: Bool = false

    /// Feedback tokens for the current track (used for library add/remove).
    var currentTrackFeedbackTokens: FeedbackTokens?

    /// Whether the lyrics panel is visible.
    var showLyrics: Bool = false {
        didSet {
            // Mutual exclusivity: opening lyrics closes queue
            if self.showLyrics, self.showQueue {
                self.showQueue = false
            }
        }
    }

    /// Display mode for the queue panel (popup vs side panel).
    var queueDisplayMode: QueueDisplayMode = .popup

    /// UserDefaults key for persisting queue display mode.
    static let queueDisplayModeKey = "optitube.queue.displayMode"

    /// Undo/redo history for queue (up to 10 states). In-memory only.
    private var queueUndoHistory: [([Track], Int)] = []
    private var queueRedoHistory: [([Track], Int)] = []
    private static let queueUndoMaxCount = 10

    /// Queue index before each forward skip, used by previous() to return pre-skip item.
    private var forwardSkipIndexStack: [Int] = []


    /// Whether the queue panel is visible.
    var showQueue: Bool = false {
        didSet {
            // Mutual exclusivity: opening queue closes lyrics
            if self.showQueue, self.showLyrics {
                self.showLyrics = false
            }
        }
    }

    /// Whether the current track has video available.
    private(set) var currentTrackHasVideo: Bool = false

    /// Whether video mode is active (user has opened video window).
    /// Note: We don't auto-close based on currentTrackHasVideo here because
    /// the detection can be unreliable when video mode CSS is active.
    var showVideo: Bool = false

    /// Whether AirPlay is currently connected (playing to a wireless target).
    private(set) var isAirPlayConnected: Bool = false

    /// Whether the user has requested AirPlay this session (for persistence across track changes).
    private(set) var airPlayWasRequested: Bool = false

    /// Tracks suggested by the Intelligent Queue (Auto-Pilot).
    var autoPilotTracks: [Track] = []

    /// Whether we're currently fetching new Auto-Pilot suggestions.
    var isFetchingAutoPilot: Bool = false

    /// Manager for the sleep timer.
    var sleepTimer: SleepTimerManager = .shared

    // MARK: - Internal Properties (for extensions)

    let logger = DiagnosticsLogger.player
    var ytMusicClient: (any YTMusicClientProtocol)?

    /// Continuation token for loading more tracks in infinite mix/radio.
    var mixContinuationToken: String?

    /// Whether we're currently fetching more mix tracks.
    var isFetchingMoreMixTracks: Bool = false

    /// Background task for queue metadata enrichment.
    var enrichmentTask: Task<Void, Never>?

    /// UserDefaults key for persisting volume.
    static let volumeKey = "playerVolume"
    /// UserDefaults key for persisting volume before mute.
    static let volumeBeforeMuteKey = "playerVolumeBeforeMute"
    /// UserDefaults key for persisting shuffle state.
    static let shuffleEnabledKey = "playerShuffleEnabled"
    /// UserDefaults key for persisting repeat mode.
    static let repeatModeKey = "playerRepeatMode"

    /// Timer for driving the visualizer simulation.
    private var visualizerTimer: Timer?

    /// Flag to track when a track is nearing its end.
    var trackNearingEnd: Bool = false

    /// Flag to track when OptiTube initiated a track change.
    var isOptiTubeInitiatedPlayback: Bool = false

    /// Flag to suppress unexpected YouTube autoplay after native queue end.
    var shouldSuppressAutoplayAfterQueueEnd: Bool = false

    /// Debounces repeat-one recovery replays for bursty metadata updates.
    var lastRepeatOneRecoveryInstant: ContinuousClock.Instant?

    // MARK: - Initialization

    override init() {
        super.init()
        // Restore saved volume from UserDefaults
        if UserDefaults.standard.object(forKey: Self.volumeKey) != nil {
            let savedVolume = UserDefaults.standard.double(forKey: Self.volumeKey)
            self.volume = max(0, min(1, savedVolume))
            self.logger.info("Restored saved volume: \(self.volume)")
        }
        // Restore volumeBeforeMute for proper unmute behavior
        if UserDefaults.standard.object(forKey: Self.volumeBeforeMuteKey) != nil {
            let savedVolumeBeforeMute = UserDefaults.standard.double(forKey: Self.volumeBeforeMuteKey)
            self.volumeBeforeMute = savedVolumeBeforeMute > 0 ? savedVolumeBeforeMute : 1.0
            self.logger.info("Restored volumeBeforeMute: \(self.volumeBeforeMute)")
        } else {
            self.volumeBeforeMute = self.volume > 0 ? self.volume : 1.0
        }

        // Restore shuffle and repeat settings if enabled in settings
        if SettingsManager.shared.rememberPlaybackSettings {
            if UserDefaults.standard.object(forKey: Self.shuffleEnabledKey) != nil {
                self.shuffleEnabled = UserDefaults.standard.bool(forKey: Self.shuffleEnabledKey)
                self.logger.info("Restored shuffle state: \(self.shuffleEnabled)")
            }

            if let savedRepeatMode = UserDefaults.standard.string(forKey: Self.repeatModeKey) {
                switch savedRepeatMode {
                case "all":
                    self.repeatMode = .all
                case "one":
                    self.repeatMode = .one
                case "off":
                    self.repeatMode = .off
                default:
                    self.logger.warning("Unexpected repeat mode value in UserDefaults: \(savedRepeatMode), defaulting to off")
                    self.repeatMode = .off
                }
                self.logger.info("Restored repeat mode: \(String(describing: self.repeatMode))")
            }
        }

        if let savedMode = UserDefaults.standard.string(forKey: Self.queueDisplayModeKey),
           let mode = QueueDisplayMode(rawValue: savedMode)
        {
            self.queueDisplayMode = mode
            self.logger.info("Restored queue display mode: \(mode.displayName)")
        }

        // Start visualizer simulation timer
        self.startVisualizerTimer()

        // Load mock state for UI tests
        self.loadMockStateIfNeeded()

        // Start background queue metadata enrichment.
        self.startQueueEnrichmentService()
    }

    /// Loads mock player state from environment variables for UI testing.
    private func loadMockStateIfNeeded() {
        guard UITestConfig.isUITestMode else { return }

        // Load mock current track
        if let jsonString = UITestConfig.environmentValue(for: UITestConfig.mockCurrentTrackKey),
           let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = dict["id"] as? String,
           let title = dict["title"] as? String,
           let videoId = dict["videoId"] as? String
        {
            let artist = dict["artist"] as? String ?? "Unknown Artist"
            let duration: TimeInterval? = (dict["duration"] as? Int).map { TimeInterval($0) }
            self.currentTrack = Track(
                id: id,
                title: title,
                artists: [Artist(id: "mock-artist", name: artist)],
                album: nil,
                duration: duration,
                thumbnailURL: nil,
                videoId: videoId
            )
            self.logger.debug("Loaded mock current track: \(title)")
        }

        // Load mock playing state
        if let isPlayingString = UITestConfig.environmentValue(for: UITestConfig.mockIsPlayingKey) {
            let isPlaying = isPlayingString == "true"
            self.state = isPlaying ? .playing : .paused
            self.logger.debug("Loaded mock playing state: \(isPlaying)")
        }

        // Load mock video availability
        if let hasVideoString = UITestConfig.environmentValue(for: UITestConfig.mockHasVideoKey) {
            let hasVideo = hasVideoString == "true"
            self.currentTrackHasVideo = hasVideo
            self.logger.debug("Loaded mock video availability: \(hasVideo)")
        }
    }

    /// Sets the YTMusicClient for API calls (dependency injection).
    func setYTMusicClient(_ client: any YTMusicClientProtocol) {
        self.ytMusicClient = client
    }

    /// Whether pending track should auto-load immediately.
    var shouldAutoloadPendingVideo: Bool {
        !self.isPendingRestoredLoadDeferred
    }

    /// Whether pending track must be loaded before playback can resume.
    var shouldLoadPendingVideoBeforePlayback: Bool {
        guard let pendingPlayVideoId = self.pendingPlayVideoId else { return false }
        return SingletonPlayerWebView.shared.currentVideoId != pendingPlayVideoId
    }

    /// Clears one-shot restoration state after reconciliation completes.
    func clearRestoredPlaybackSessionState() {
        self.pendingRestoredSeek = nil
        self.isPendingRestoredLoadDeferred = false
        self.isRestoringPlaybackSession = false
        self.shouldAutoResumeAfterRestoredLoad = false
    }

    /// Begins loading a restored session into the WebView.
    func beginRestoredPlaybackLoad(autoResumeAfterSeek: Bool) {
        self.isPendingRestoredLoadDeferred = false
        self.isRestoringPlaybackSession = true
        self.shouldAutoResumeAfterRestoredLoad = autoResumeAfterSeek
        if autoResumeAfterSeek {
            self.state = .loading
        }
    }

    /// Clears skip history when queue order changes externally.
    func clearForwardSkipNavigationStack() {
        self.forwardSkipIndexStack.removeAll()
    }

    /// Pushes current index before next() leaves it.
    func pushForwardSkipStackIfLeavingIndex(for newIndex: Int) {
        let fromIndex = self.currentIndex
        guard fromIndex != newIndex else { return }
        self.forwardSkipIndexStack.append(fromIndex)
    }

    // MARK: - Public Methods

    /// Plays a track by video ID.
    func play(videoId: String) async {
        self.logger.debug("play() called with videoId: \(videoId)")
        self.logger.info("Playing video: \(videoId)")
        self.playbackWillStart?()
        self.clearRestoredPlaybackSessionState()
        self.state = .loading
        self.trackNearingEnd = false
        self.shouldSuppressAutoplayAfterQueueEnd = false

        // Create a minimal Track object for now
        self.currentTrack = Track(
            id: videoId,
            title: "Loading...",
            artists: [],
            album: nil,
            duration: nil,
            thumbnailURL: nil,
            videoId: videoId
        )

        self.pendingPlayVideoId = videoId

        // If user has already interacted this session, auto-play without popup
        if self.hasUserInteractedThisSession {
            self.logger.info("User has interacted before, auto-playing without popup")
            self.showMiniPlayer = false
            // Load the video directly - WebView session should allow autoplay
            SingletonPlayerWebView.shared.loadVideo(videoId: videoId)
        } else {
            // First time: show the mini player for user interaction
            self.showMiniPlayer = true
            self.logger.info("Showing mini player for first-time user interaction")
        }

        // Fetch full track metadata in the background to get feedbackTokens
        await self.fetchTrackMetadata(videoId: videoId)
    }

    /// Plays a track.
    func play(track: Track) async {
        self.logger.info("Playing track: \(track.title)")
        self.playbackWillStart?()
        self.clearRestoredPlaybackSessionState()
        self.state = .loading
        self.trackNearingEnd = false
        self.shouldSuppressAutoplayAfterQueueEnd = false
        self.currentTrack = track

        // Mark that we initiated this playback (to detect and correct YouTube's autoplay override)
        self.isOptiTubeInitiatedPlayback = true

        // Use existing feedbackTokens if the track already has them
        if let tokens = track.feedbackTokens {
            self.currentTrackFeedbackTokens = tokens
            self.currentTrackInLibrary = track.isInLibrary ?? false
            if let likeStatus = track.likeStatus {
                self.currentTrackLikeStatus = likeStatus
            }
        }

        self.pendingPlayVideoId = track.videoId

        // If user has already interacted this session, auto-play without popup
        if self.hasUserInteractedThisSession {
            self.logger.info("User has interacted before, auto-playing without popup")
            self.showMiniPlayer = false
            SingletonPlayerWebView.shared.loadVideo(videoId: track.videoId)
        } else {
            // First time: show the mini player for user interaction
            self.showMiniPlayer = true
            self.logger.info("Showing mini player for first-time user interaction")
        }

        // Fetch full track metadata if we don't have feedbackTokens
        if track.feedbackTokens == nil {
            await self.fetchTrackMetadata(videoId: track.videoId)
        }
        
        // Restore volume if it was left at 0 by a fade or sleep timer
        if self.volume == 0 && !self.isMuted {
             await self.setVolume(self.volumeBeforeMute > 0 ? self.volumeBeforeMute : 1.0)
        }
    }

    /// Called when the mini player confirms playback has started.
    func confirmPlaybackStarted() {
        self.showMiniPlayer = false
        self.state = .playing
        self.hasUserInteractedThisSession = true
        self.logger.info("Playback confirmed started, user interaction recorded")
    }

    /// Called when the mini player is dismissed.
    func miniPlayerDismissed() {
        self.showMiniPlayer = false
        if self.state == .loading {
            self.state = .idle
        }
    }

    func markPlaybackEnded() {
        self.state = .ended
    }

    /// Updates playback state from the persistent WebView observer.
    func updatePlaybackState(isPlaying: Bool, progress: Double, duration: Double) {
        let previousProgress = self.progress
        self.currentTimeMs = Int(progress * 1000)

        if isPlaying {
            EqualizerService.shared.retryStartIfEnabled()
        }

        guard !self.isRestoringPlaybackSession else {
            self.reconcileRestoredPlaybackState(
                isPlaying: isPlaying,
                progress: progress,
                duration: duration,
                previousProgress: previousProgress
            )
            return
        }

        self.applyObservedPlaybackState(
            isPlaying: isPlaying,
            progress: progress,
            duration: duration,
            previousProgress: previousProgress
        )
    }

    /// Updates track metadata when track changes (e.g., via next/previous).
    /// Also handles enforcing our queue when YouTube autoplay kicks in.
    func updateTrackMetadata(title: String, artist: String, thumbnailUrl: String, videoId observedVideoId: String?) {
        self.logger.debug("Track metadata updated: \(title) - \(artist)")

        let thumbnailURL = URL(string: thumbnailUrl)
        let artistObj = Artist(id: "unknown", name: artist)
        let normalizedObservedVideoId: String? = if let observedVideoId, !observedVideoId.isEmpty {
            observedVideoId
        } else {
            nil
        }
        let resolvedVideoId = normalizedObservedVideoId ?? self.currentTrack?.videoId ?? self.pendingPlayVideoId ?? "unknown"
        let trackChanged = self.currentTrack?.title != title
            || self.currentTrack?.artistsDisplay != artist
            || self.currentTrack?.videoId != resolvedVideoId

        // Update Menu Bar title
        MenuBarController.shared.updateTitle(title)

        if trackChanged,
           self.shouldSuppressAutoplayAfterQueueEnd,
           let currentQueueTrack = self.queue[safe: self.currentIndex]
        {
            let mismatch = normalizedObservedVideoId.map { $0 != currentQueueTrack.videoId }
                ?? (title != currentQueueTrack.title || artist != currentQueueTrack.artistsDisplay)
            if mismatch {
                self.markPlaybackEnded()
                self.logger.info("Suppressing unexpected autoplay after native queue ended")
                self.currentTrack = currentQueueTrack
                Task {
                    await self.pause()
                }
                return
            }
        }

        // If we initiated playback (e.g., via next() with shuffle), check if YouTube loaded a different track
        // This happens when the WebView's media session intercepts media keys and triggers YouTube's own next
        if trackChanged, self.isOptiTubeInitiatedPlayback, !self.queue.isEmpty {
            if let intendedTrack = queue[safe: currentIndex],
               intendedTrack.videoId != resolvedVideoId
            {
                if let observedVideoId = normalizedObservedVideoId,
                   self.queue.contains(where: { $0.videoId == observedVideoId })
                {
                    self.isOptiTubeInitiatedPlayback = false
                } else {
                    self.logger.info("YouTube loaded different track '\(title)' (\(resolvedVideoId)), re-playing intended track '\(intendedTrack.title)'")
                    // Clear the flag to prevent infinite loop
                    self.isOptiTubeInitiatedPlayback = false
                    Task {
                        await self.play(track: intendedTrack)
                    }
                    return
                }
            }
            // Track matches what we wanted, clear the flag
            self.isOptiTubeInitiatedPlayback = false
        }

        // If track changed and we have a queue, check if YouTube autoplay kicked in (track ending naturally)
        if trackChanged, !self.queue.isEmpty, self.trackNearingEnd {
            self.trackNearingEnd = false

            if let expectedNextIndex = self.expectedQueueIndexAfterCurrentTrack(),
               let expectedNextTrack = self.queue[safe: expectedNextIndex]
            {
                let mismatch = normalizedObservedVideoId.map { $0 != expectedNextTrack.videoId }
                    ?? (title != expectedNextTrack.title || artist != expectedNextTrack.artistsDisplay)
                if mismatch {
                    if self.repeatMode == .one {
                        if let currentTrack = self.queue[safe: self.currentIndex] {
                            Task {
                                await self.play(track: currentTrack)
                            }
                        }
                        return
                    }
                    self.logger.info("YouTube autoplay detected, overriding with queue track")
                    Task {
                        await self.next()
                    }
                    return
                } else {
                    self.currentIndex = expectedNextIndex
                    self.logger.info("Track advanced to queue index \(expectedNextIndex)")
                    self.saveQueueForPersistence()
                }
            } else if !self.canAdvanceNativeQueueAfterTrackEnd {
                self.shouldSuppressAutoplayAfterQueueEnd = true
                self.markPlaybackEnded()
                Task {
                    await self.pause()
                }
                return
            }
        }

        if !self.queue.isEmpty,
           let observedVideoId = normalizedObservedVideoId,
           let currentQueueTrack = self.queue[safe: self.currentIndex],
           currentQueueTrack.videoId != observedVideoId
        {
            if self.repeatMode == .one {
                self.logger.info("Repeat one: observed track drift, re-playing queue track")
                Task {
                    await self.play(track: currentQueueTrack)
                }
                return
            }

            if let matchingIndex = self.queue.firstIndex(where: { $0.videoId == observedVideoId }),
               let matchingTrack = self.queue[safe: matchingIndex]
            {
                if matchingIndex != self.currentIndex {
                    self.currentIndex = matchingIndex
                    self.saveQueueForPersistence()
                }

                if self.currentTrack?.videoId != matchingTrack.videoId {
                    self.resetTrackStatus()
                }
                self.currentTrack = matchingTrack
                return
            }

            self.logger.info("Observed track drifted from native queue, re-playing intended queue track")
            Task {
                await self.play(track: currentQueueTrack)
            }
            return
        }

        if self.repeatMode == .one, let queued = self.queue[safe: self.currentIndex] {
            self.currentTrack = queued
            return
        }

        self.currentTrack = Track(
            id: resolvedVideoId,
            title: title,
            artists: [artistObj],
            album: nil,
            duration: self.duration > 0 ? self.duration : nil,
            thumbnailURL: thumbnailURL,
            videoId: resolvedVideoId
        )

        // Report track started for scrobbling
        if trackChanged, let track = self.currentTrack {
            ScrobbleService.shared.trackStarted(track)
        }

        // Reset like/library status when track changes
        if trackChanged {
            self.resetTrackStatus()
        }
    }

    /// Grace period instant - don't auto-close video window shortly after opening (uses monotonic clock)
    private var videoWindowOpenedAt: ContinuousClock.Instant?

    /// Updates whether the current track has video available.
    /// Note: This only affects the UI (enabling/disabling the video button).
    /// It does NOT auto-close an open video window, since hasVideo detection
    /// can be unreliable when the video element has been extracted by video mode CSS.
    func updateVideoAvailability(hasVideo: Bool) {
        let previousValue = self.currentTrackHasVideo
        self.currentTrackHasVideo = hasVideo

        // Don't auto-close the video window based on hasVideo detection.
        // The detection is unreliable when video mode is active because:
        // 1. The video element has been extracted from its original DOM location
        // 2. The Track/Video toggle buttons may be hidden by our CSS
        // 3. Resize or other layout changes can temporarily break detection
        //
        // Instead, we rely on trackChanged detection in the Coordinator to close
        // the video window when a new track starts.

        if previousValue != hasVideo {
            self.logger.debug("Video availability updated: \(hasVideo)")
        }
    }

    /// Called when video window opens to start grace period
    func videoWindowDidOpen() {
        self.videoWindowOpenedAt = ContinuousClock.now
        self.logger.debug("videoWindowDidOpen: grace period started")
    }

    /// Called when video window closes to clear grace period
    func videoWindowDidClose() {
        self.videoWindowOpenedAt = nil
        self.logger.debug("videoWindowDidClose: grace period cleared")
    }

    /// Returns true if video window was recently opened (within grace period)
    /// This is used to ignore spurious trackChanged events during video mode setup
    var isVideoGracePeriodActive: Bool {
        guard let openedAt = self.videoWindowOpenedAt else { return false }
        // 3 second grace period to allow video mode setup to complete
        return ContinuousClock.now - openedAt < .seconds(3)
    }

    private var canAdvanceNativeQueueAfterTrackEnd: Bool {
        self.shuffleEnabled
            || self.repeatMode == .one
            || self.currentIndex < self.queue.count - 1
            || self.repeatMode == .all
            || self.mixContinuationToken != nil
    }

    private func expectedQueueIndexAfterCurrentTrack() -> Int? {
        guard !self.queue.isEmpty else { return nil }
        if self.repeatMode == .one {
            return self.currentIndex
        }
        guard !self.shuffleEnabled else { return nil }
        if self.currentIndex < self.queue.count - 1 {
            return self.currentIndex + 1
        }
        if self.repeatMode == .all {
            return 0
        }
        return nil
    }

    /// Handles natural track completion reported by WebView.
    func handleTrackEnded(observedVideoId: String?) async {
        self.logger.debug("Track ended reported by WebView: \(observedVideoId ?? "unknown")")
        self.trackNearingEnd = false

        guard !self.queue.isEmpty else {
            if self.repeatMode == .one, let currentTrack {
                await self.play(track: currentTrack)
                return
            }
            self.markPlaybackEnded()
            return
        }

        if let observedVideoId,
           let expectedVideoId = self.queue[safe: self.currentIndex]?.videoId,
           observedVideoId != expectedVideoId,
           self.repeatMode != .one
        {
            self.logger.debug("Ignoring stale track-ended event for \(observedVideoId); expected \(expectedVideoId)")
            return
        }

        guard self.canAdvanceNativeQueueAfterTrackEnd else {
            self.shouldSuppressAutoplayAfterQueueEnd = true
            self.markPlaybackEnded()
            await self.pause()
            return
        }

        self.shouldSuppressAutoplayAfterQueueEnd = false
        if self.repeatMode == .one, let currentTrack = self.queue[safe: self.currentIndex] {
            if self.hasUserInteractedThisSession, self.pendingPlayVideoId == currentTrack.videoId {
                SingletonPlayerWebView.shared.restartInPlaceFromBeginning()
                self.state = .playing
            } else {
                await self.play(track: currentTrack)
            }
            return
        }

        await self.next()
    }

    /// Toggles play/pause.
    func playPause() async {
        self.logger.debug("Toggle play/pause")

        if self.isPendingRestoredLoadDeferred || self.pendingPlayVideoId != nil && self.shouldLoadPendingVideoBeforePlayback {
            await self.resume()
            return
        }

        self.clearRestoredPlaybackSessionState()

        // Use singleton WebView if we have a pending video
        if self.pendingPlayVideoId != nil {
            SingletonPlayerWebView.shared.playPause()
        } else if self.isPlaying {
            await self.pause()
        } else {
            await self.resume()
        }
    }

    /// Pauses playback.
    func pause() async {
        self.logger.debug("Pausing playback")

        if self.isPendingRestoredLoadDeferred {
            self.state = .paused
            return
        }

        self.clearRestoredPlaybackSessionState()
        if self.pendingPlayVideoId != nil {
            SingletonPlayerWebView.shared.pause()
        } else {
            await self.evaluatePlayerCommand("pause")
        }
    }

    /// Resumes playback.
    func resume() async {
        self.playbackWillStart?()
        self.logger.debug("Resuming playback")

        guard let pendingPlayVideoId = self.pendingPlayVideoId else {
            self.clearRestoredPlaybackSessionState()
            await self.evaluatePlayerCommand("play")
            return
        }

        let shouldLoadPendingVideo = self.shouldLoadPendingVideoBeforePlayback
        if self.isPendingRestoredLoadDeferred {
            self.beginRestoredPlaybackLoad(autoResumeAfterSeek: self.hasUserInteractedThisSession)
        } else {
            self.clearRestoredPlaybackSessionState()
        }

        if shouldLoadPendingVideo {
            if self.hasUserInteractedThisSession {
                self.showMiniPlayer = false
                self.state = .loading
                SingletonPlayerWebView.shared.loadVideo(videoId: pendingPlayVideoId)
            } else {
                self.showMiniPlayer = true
                self.logger.info("Showing mini player so the user can resume playback")
            }
            return
        }

        if self.pendingPlayVideoId != nil {
            SingletonPlayerWebView.shared.play()
        } else {
            await self.evaluatePlayerCommand("play")
        }
    }

    /// Skips to next track.
    func next() async {
        self.logger.debug("Skipping to next track")
        self.clearRestoredPlaybackSessionState()
        
        // Record skip event if track was playing but skipped early
        if let current = currentTrack, self.progress < (self.duration * 0.8) {
             HistoryManager.shared.recordEvent(track: current, durationWatched: self.progress, wasSkipped: true)
        }

        await performCrossfade { [weak self] in
            guard let self = self else { return }

            // Prioritize local queue if we have one
            if !self.queue.isEmpty {
                // Handle shuffle mode - pick random track
                if self.shuffleEnabled {
                    let randomIndex = Int.random(in: 0 ..< self.queue.count)
                    self.pushForwardSkipStackIfLeavingIndex(for: randomIndex)
                    self.currentIndex = randomIndex
                    if let nextTrack = queue[safe: currentIndex] {
                        await self.play(track: nextTrack)
                    }
                    // Check if we should fetch more tracks
                    await self.fetchMoreMixTracksIfNeeded()
                    self.saveQueueForPersistence()
                    return
                }

                // Normal next behavior
                if self.currentIndex < self.queue.count - 1 {
                    self.pushForwardSkipStackIfLeavingIndex(for: self.currentIndex + 1)
                    self.currentIndex += 1
                    if let nextTrack = queue[safe: currentIndex] {
                        await self.play(track: nextTrack)
                    }
                    // Check if we should fetch more tracks
                    await self.fetchMoreMixTracksIfNeeded()
                    self.saveQueueForPersistence()
                } else if self.repeatMode == .all {
                    // Loop back to start if repeat all is enabled
                    self.pushForwardSkipStackIfLeavingIndex(for: 0)
                    self.currentIndex = 0
                    if let firstTrack = queue.first {
                        await self.play(track: firstTrack)
                    }
                    self.saveQueueForPersistence()
                } else if self.mixContinuationToken != nil {
                    // At end of queue but have continuation - fetch more and continue
                    let previousCount = self.queue.count
                    await self.fetchMoreMixTracksIfNeeded()
                    // Only advance if new tracks were actually added
                    if self.queue.count > previousCount {
                        self.pushForwardSkipStackIfLeavingIndex(for: self.currentIndex + 1)
                        self.currentIndex += 1
                        if let nextTrack = queue[safe: currentIndex] {
                            await self.play(track: nextTrack)
                        }
                        self.saveQueueForPersistence()
                    }
                }
                // At end of queue with repeat off and no continuation, don't do anything
                // UNLESS Auto-Pilot is enabled
                if SettingsManager.shared.autoPilotEnabled, !self.autoPilotTracks.isEmpty {
                    self.logger.info("Manual queue exhausted, transitioning to Auto-Pilot")
                    if let nextTrack = self.autoPilotTracks.first {
                        self.autoPilotTracks.removeFirst()
                        await self.play(track: nextTrack)
                        
                        // Refill suggestions in background
                        Task { await self.fetchAutoPilotTracksIfNeeded() }
                        return
                    }
                }
                
                return
            }

            // Fall back to YouTube's next if no local queue
            if self.pendingPlayVideoId != nil {
                SingletonPlayerWebView.shared.next()
            }
        }
    }

    /// Goes to previous track.
    func previous() async {
        self.logger.debug("Going to previous track")
        self.clearRestoredPlaybackSessionState()

        await performCrossfade { [weak self] in
            guard let self = self else { return }

            // Prioritize local queue if we have one
            if !self.queue.isEmpty {
                if self.progress > 3 {
                    await self.seek(to: 0)
                    return
                }

                if let priorIndex = self.forwardSkipIndexStack.popLast(),
                   self.queue.indices.contains(priorIndex)
                {
                    self.currentIndex = priorIndex
                    if let prevTrack = self.queue[safe: priorIndex] {
                        await self.play(track: prevTrack)
                    }
                    self.saveQueueForPersistence()
                    return
                }

                if self.currentIndex > 0 {
                    self.currentIndex -= 1
                    if let prevTrack = queue[safe: currentIndex] {
                        await self.play(track: prevTrack)
                    }
                    self.saveQueueForPersistence()
                } else {
                    // At start of queue, just restart current track
                    await self.seek(to: 0)
                }
                return
            }

            // Fall back to YouTube's previous if no local queue
            if self.pendingPlayVideoId != nil {
                if self.progress > 3 {
                    await self.seek(to: 0)
                } else {
                    SingletonPlayerWebView.shared.previous()
                }
            } else if self.progress > 3 {
                await self.seek(to: 0)
            }
        }
    }

    /// Seeks to a specific time.
    func seek(to time: TimeInterval) async {
        let clampedTime = self.duration > 0 ? min(max(time, 0), self.duration) : max(time, 0)
        self.logger.debug("Seeking to \(clampedTime)")

        if self.isPendingRestoredLoadDeferred {
            self.progress = clampedTime
            self.pendingRestoredSeek = clampedTime
            return
        }

        self.clearRestoredPlaybackSessionState()
        if self.pendingPlayVideoId != nil {
            SingletonPlayerWebView.shared.seek(to: clampedTime)
            self.progress = clampedTime
        } else {
            await self.evaluatePlayerCommand("seekTo(\(clampedTime), true)")
        }
    }

    /// Sets the volume.
    func setVolume(_ value: Double) async {
        let clampedValue = max(0, min(1, value))
        self.volume = clampedValue

        // Persist volume to UserDefaults (including mute state of 0)
        UserDefaults.standard.set(clampedValue, forKey: Self.volumeKey)

        if self.pendingPlayVideoId != nil {
            SingletonPlayerWebView.shared.setVolume(clampedValue)
        } else {
            await self.evaluatePlayerCommand("setVolume(\(Int(clampedValue * 100)))")
        }
    }

    /// Toggles mute state. Remembers previous volume for unmuting.
    func toggleMute() async {
        if self.isMuted {
            // Unmute - restore previous volume
            let restoredVolume = self.volumeBeforeMute > 0 ? self.volumeBeforeMute : 1.0
            await self.setVolume(restoredVolume)
            self.logger.info("Unmuted, volume restored to \(restoredVolume)")
        } else {
            // Mute - save current volume and set to 0
            self.volumeBeforeMute = self.volume
            // Persist volumeBeforeMute so we can restore after app restart
            UserDefaults.standard.set(self.volumeBeforeMute, forKey: Self.volumeBeforeMuteKey)
            await self.setVolume(0)
            self.logger.info("Muted")
        }
    }

    /// Toggles shuffle mode.
    func toggleShuffle() {
        self.shuffleEnabled.toggle()
        // Persist shuffle state to UserDefaults if setting is enabled
        if SettingsManager.shared.rememberPlaybackSettings {
            UserDefaults.standard.set(self.shuffleEnabled, forKey: Self.shuffleEnabledKey)
        }
        let status = self.shuffleEnabled ? "enabled" : "disabled"
        self.logger.info("Shuffle mode: \(status)")
    }

    /// Cycles through repeat modes: off -> all -> one -> off.
    func cycleRepeatMode() {
        switch self.repeatMode {
        case .off:
            self.repeatMode = .all
        case .all:
            self.repeatMode = .one
        case .one:
            self.repeatMode = .off
        }
        // Persist repeat mode to UserDefaults if setting is enabled
        if SettingsManager.shared.rememberPlaybackSettings {
            let modeString = switch self.repeatMode {
            case .off:
                "off"
            case .all:
                "all"
            case .one:
                "one"
            }
            UserDefaults.standard.set(modeString, forKey: Self.repeatModeKey)
        }
        let mode = self.repeatMode
        self.logger.info("Repeat mode: \(String(describing: mode))")
    }

    /// Stops playback and clears state.
    func stop() async {
        self.logger.debug("Stopping playback")
        self.clearRestoredPlaybackSessionState()
        await self.evaluatePlayerCommand("pauseVideo()")
        self.state = .idle
        self.trackNearingEnd = false
        self.isOptiTubeInitiatedPlayback = false
        self.shouldSuppressAutoplayAfterQueueEnd = false
        self.currentTrack = nil
        self.progress = 0
        self.duration = 0
    }

    /// Show the AirPlay picker for selecting audio output devices.
    func showAirPlayPicker() {
        self.airPlayWasRequested = true
        SingletonPlayerWebView.shared.showAirPlayPicker()
    }

    /// Updates the AirPlay connection status from the WebView.
    func updateAirPlayStatus(isConnected: Bool, wasRequested: Bool = false) {
        self.isAirPlayConnected = isConnected
        if wasRequested {
            self.airPlayWasRequested = true
        }
    }

    private func applyObservedPlaybackState(
        isPlaying: Bool,
        progress: Double,
        duration: Double,
        previousProgress: TimeInterval
    ) {
        self.progress = progress
        self.duration = duration

        if isPlaying {
            self.state = .playing
        } else if self.state == .playing {
            self.state = .paused
        }

        if duration > 0, progress >= duration - 2, previousProgress < duration - 2 {
            self.trackNearingEnd = true
            if let track = self.currentTrack {
                HistoryManager.shared.recordEvent(track: track, durationWatched: progress, wasSkipped: false)
            }
        }

        ScrobbleService.shared.updateProgress(progress: progress, duration: duration)
        if let track = self.currentTrack {
            DiscordRPCManager.shared.updatePresence(track: track, isPlaying: isPlaying, progress: progress)
        }

        self.syncWithWidget()
    }

    private func reconcileRestoredPlaybackState(
        isPlaying: Bool,
        progress: Double,
        duration: Double,
        previousProgress: TimeInterval
    ) {
        let resolvedDuration = duration > 0 ? duration : self.duration
        self.duration = resolvedDuration

        if let targetProgress = self.pendingRestoredSeek {
            let clampedTarget = resolvedDuration > 0 ? min(max(targetProgress, 0), resolvedDuration) : max(targetProgress, 0)
            self.progress = clampedTarget

            let tolerance: TimeInterval = 1.5
            let isAtTarget = abs(progress - clampedTarget) <= tolerance
            if !isAtTarget, resolvedDuration > 0 {
                SingletonPlayerWebView.shared.seek(to: clampedTarget)
                if isPlaying {
                    SingletonPlayerWebView.shared.pause()
                }
                self.state = self.shouldAutoResumeAfterRestoredLoad ? .loading : .paused
                return
            }

            self.progress = isAtTarget ? progress : clampedTarget
            self.pendingRestoredSeek = nil
            if self.shouldAutoResumeAfterRestoredLoad {
                self.clearRestoredPlaybackSessionState()
                if isPlaying {
                    self.state = .playing
                } else {
                    SingletonPlayerWebView.shared.play()
                }
            } else {
                if isPlaying {
                    SingletonPlayerWebView.shared.pause()
                }
                self.state = .paused
                self.clearRestoredPlaybackSessionState()
            }
            return
        }

        self.progress = progress > 0 ? progress : previousProgress
        if self.shouldAutoResumeAfterRestoredLoad {
            self.state = .loading
            if isPlaying {
                self.clearRestoredPlaybackSessionState()
                self.state = .playing
            } else if resolvedDuration > 0 {
                self.clearRestoredPlaybackSessionState()
                SingletonPlayerWebView.shared.play()
            }
            return
        }

        self.state = .paused
        if !isPlaying, resolvedDuration > 0 {
            self.clearRestoredPlaybackSessionState()
        }
    }

    // MARK: - Private Methods

    /// Legacy method for evaluating player commands - now delegates to SingletonPlayerWebView.
    private func evaluatePlayerCommand(_ command: String) async {
        // Commands are now routed through SingletonPlayerWebView
        switch command {
        case "pause", "pauseVideo()":
            SingletonPlayerWebView.shared.pause()
        case "play", "playVideo()":
            SingletonPlayerWebView.shared.play()
        default:
            if command.hasPrefix("seekTo(") {
                let timeStr = command.dropFirst(7).prefix(while: { $0 != "," && $0 != ")" })
                if let time = Double(timeStr) {
                    SingletonPlayerWebView.shared.seek(to: time)
                }
            } else if command.hasPrefix("setVolume(") {
                let volStr = command.dropFirst(10).dropLast()
                if let vol = Int(volStr) {
                    SingletonPlayerWebView.shared.setVolume(Double(vol) / 100.0)
                }
            }
        }
    }

    // MARK: - Color Palette Support

    /// Updates the color palette using the current track's thumbnail.
    private func updateColorPalette() async {
        guard let url = currentTrack?.thumbnailURL else {
            self.currentArtworkPalette = .default
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let palette = await ColorExtractor.extractPalette(from: data)
            self.currentArtworkPalette = palette
            self.logger.debug("Updated color palette for track: \(self.currentTrack?.title ?? "unknown")")
        } catch {
            self.logger.warning("Failed to extract color palette: \(error.localizedDescription)")
            self.currentArtworkPalette = .default
        }
    }

    // MARK: - Visualizer Simulation

    /// Starts a timer that updates audio levels when playing.
    private func startVisualizerTimer() {
        self.visualizerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevels()
            }
        }
    }

    /// Updates the mock audio level data.
    private func updateAudioLevels() {
        guard self.isPlaying, self.activeVisualizer != .none else {
            // Decay to zero if not playing or visualizer is disabled
            for i in 0 ..< self.audioLevels.count {
                self.audioLevels[i] *= 0.8
                if self.audioLevels[i] < 0.01 { self.audioLevels[i] = 0 }
            }
            return
        }

        // Generate some smooth random noise for the visualizer
        for i in 0 ..< self.audioLevels.count {
            let target = CGFloat.random(in: 0.2 ... 1.0)
            // Smoothly interpolate towards target
            self.audioLevels[i] = self.audioLevels[i] * 0.4 + target * 0.6
        }
    }

    // MARK: - Widget Synchronization

    /// Synchronizes the current playback state with the desktop widget.
    func syncWithWidget() {
        let data = WidgetPlaybackData(
            title: currentTrack?.title ?? "Not Playing",
            artist: currentTrack?.artistsDisplay ?? "",
            artworkURL: currentTrack?.thumbnailURL?.highQualityThumbnailURL,
            isPlaying: isPlaying
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            WidgetPlaybackData.defaults?.set(encoded, forKey: WidgetPlaybackData.dataKey)
        }
    }

    // MARK: - Audio Crossfade

    /// Performs a smooth 220ms crossfade around an asynchronous action (like track skip).
    private func performCrossfade(action: @escaping () async -> Void) async {
        let fadeDuration = 110
        let currentVol = self.volume
        
        // 1. Fade out
        await withCheckedContinuation { continuation in
            SingletonPlayerWebView.shared.fadeVolume(to: 0, durationMs: fadeDuration) {
                continuation.resume()
            }
        }
        
        // 2. Perform track change
        await action()
        
        // 3. Fade in
        await withCheckedContinuation { continuation in
            SingletonPlayerWebView.shared.fadeVolume(to: currentVol, durationMs: fadeDuration) {
                continuation.resume()
            }
        }
    }

    // MARK: - AirPlay and Group Play Support

    /// Updates the AirPlay connectivity status.
    func updateAirPlayStatus(_ active: Bool) {
        self.isAirPlayConnected = active
    }

    /// Conceptually synchronizes playback state for "Group Play".
    /// In a production environment, this would broadcast via Multicast or a WebSocket hub.
    func syncPlayback() {
        // Concept: Broadcast (videoId, progress, isPlaying)
        self.logger.info("Syncing playback for Group Play: \(self.currentTrack?.title ?? "None")")
    }

    // MARK: - Queue Undo / Redo

    /// Toggles between popup and side panel queue display modes.
    func toggleQueueDisplayMode() {
        if self.queueDisplayMode == .popup {
            self.queueDisplayMode = .sidepanel
        } else {
            self.queueDisplayMode = .popup
        }
        UserDefaults.standard.set(self.queueDisplayMode.rawValue, forKey: Self.queueDisplayModeKey)
        self.logger.info("Queue display mode: \(self.queueDisplayMode.displayName)")
    }

    /// Applies internal playback values that use private setters.
    /// This keeps restoration logic in extensions while preserving encapsulation.
    func applyInternalPlaybackSnapshot(
        pendingVideoId: String?,
        hasVideo: Bool,
        progress: TimeInterval,
        duration: TimeInterval,
        state: PlaybackState
    ) {
        self.pendingPlayVideoId = pendingVideoId
        self.currentTrackHasVideo = hasVideo
        self.progress = progress
        self.duration = duration
        self.state = state
    }

    /// Whether queue undo is available.
    var canUndoQueue: Bool {
        !self.queueUndoHistory.isEmpty
    }

    /// Whether queue redo is available.
    var canRedoQueue: Bool {
        !self.queueRedoHistory.isEmpty
    }

    /// Records current queue state for undo (call before mutating queue). Clears redo. Keeps up to 3 states.
    func recordQueueStateForUndo() {
        let state = (self.queue, self.currentIndex)
        self.queueUndoHistory.append(state)
        if self.queueUndoHistory.count > Self.queueUndoMaxCount {
            self.queueUndoHistory.removeFirst()
        }
        self.queueRedoHistory.removeAll()
        self.logger.debug("Recorded queue state for undo, undo count: \(self.queueUndoHistory.count)")
    }

    /// Restores the previous queue state. Does nothing if undo history is empty.
    func undoQueue() {
        guard let state = self.queueUndoHistory.popLast() else { return }
        let (previousQueue, previousIndex) = state
        self.queueRedoHistory.append((self.queue, self.currentIndex))
        self.queue = previousQueue
        self.currentIndex = min(previousIndex, max(0, previousQueue.count - 1))
        self.saveQueueForPersistence()
        self.clearForwardSkipNavigationStack()
        self.logger.info("Undid queue to \(previousQueue.count) songs at index \(self.currentIndex)")
    }

    /// Restores the next queue state after an undo. Does nothing if redo history is empty.
    func redoQueue() {
        guard let state = self.queueRedoHistory.popLast() else { return }
        let (nextQueue, nextIndex) = state
        self.queueUndoHistory.append((self.queue, self.currentIndex))
        self.queue = nextQueue
        self.currentIndex = min(nextIndex, max(0, nextQueue.count - 1))
        self.saveQueueForPersistence()
        self.clearForwardSkipNavigationStack()
        self.logger.info("Redid queue to \(nextQueue.count) songs at index \(self.currentIndex)")
    }

}
