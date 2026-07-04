// PlaybackArbiter.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation
import Observation

/// Ensures exactly one audio source plays at a time: starting YouTube video
/// playback pauses music, and starting music pauses video.
@MainActor
@Observable
final class PlaybackArbiter {
    /// The source that most recently started playback. Media keys route here.
    private(set) var activeSource: AppSource = .music

    private let playerService: PlaybackStore
    private let youtubePlayerService: YouTubePlayerService
    private let logger = DiagnosticsLogger.player

    init(playerService: PlaybackStore, youtubePlayerService: YouTubePlayerService) {
        self.playerService = playerService
        self.youtubePlayerService = youtubePlayerService

        youtubePlayerService.playbackWillStart = { [weak self] in
            self?.videoWillStartPlaying()
        }
    }

    /// Video playback is about to start — pause music.
    func videoWillStartPlaying() {
        self.activeSource = .video

        guard self.playerService.isPlaying else { return }
        self.logger.info("Arbiter: pausing music for video playback")
        Task {
            await self.playerService.pause()
        }
    }

    /// Music playback started — pause video.
    func musicDidStartPlaying() {
        guard self.activeSource != .music else { return }
        self.activeSource = .music

        guard self.youtubePlayerService.isPlaying else { return }
        self.logger.info("Arbiter: pausing video for music playback")
        self.youtubePlayerService.pause()
    }

    /// Whether media keys should currently control the YouTube video player.
    var routesMediaKeysToVideo: Bool {
        self.activeSource == .video && self.youtubePlayerService.currentVideo != nil
    }
}
