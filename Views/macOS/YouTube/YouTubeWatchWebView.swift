// YouTubeWatchWebView.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import AppKit
import os
import SwiftUI
import WebKit

// MARK: - YouTubeWatchWebView

/// Manages the single WebView used for regular YouTube video playback.
@MainActor
final class YouTubeWatchWebView {
    static let shared = YouTubeWatchWebView()

    private(set) var webView: WKWebView?
    var currentVideoId: String?
    private var coordinator: Coordinator?
    private let logger = DiagnosticsLogger.player
    private var pendingVideoId: String?

    /// Seek position (seconds) to apply once the next page finishes loading.
    var pendingSeek: Double?

    /// Monotonic counter for `load(videoId:)` calls.
    private var loadGeneration = 0

    /// Monotonic counter for conceal/reveal cycles (anti black-flash).
    private var concealGeneration = 0

    private init() {}

    /// Get or create the watch WebView.
    func getWebView(
        webKitManager: WebKitManager,
        playerService: YouTubePlayerService
    ) -> WKWebView {
        if let existing = webView {
            return existing
        }

        self.logger.info("Creating YouTube watch WebView")

        let coordinator = Coordinator(playerService: playerService)
        self.coordinator = coordinator

        let configuration = webKitManager.createWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "youtubePlayer")
        self.installUserScripts(
            on: configuration.userContentController,
            targetVolume: playerService.volume
        )

        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.navigationDelegate = coordinator
        newWebView.uiDelegate = coordinator
        newWebView.customUserAgent = WebKitManager.userAgent

        newWebView.underPageBackgroundColor = .clear
        // WKWebView paints an opaque background regardless of page CSS;
        // disable it so the app's glass theme shows through transparent pages.
        newWebView.setValue(false, forKey: "drawsBackground")

        #if DEBUG
            newWebView.isInspectable = true
        #endif

        self.webView = newWebView

        if let pending = self.pendingVideoId {
            self.pendingVideoId = nil
            self.loadVideo(videoId: pending)
        }

        return newWebView
    }

    /// Ensures the WebView fills the given container (reparenting if needed).
    func ensureInHierarchy(container: NSView) {
        guard let webView, webView.superview !== container else { return }
        webView.removeFromSuperview()
        container.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
    }

    /// Loads a watch page for the given video, skipping if it is already current.
    func loadVideo(videoId: String) {
        guard videoId != self.currentVideoId else {
            self.logger.debug("YouTube video \(videoId) already loaded, skipping")
            return
        }
        self.pendingSeek = nil
        self.load(videoId: videoId)
    }

    /// Forces a full reload of the given video even when it is already current,
    /// optionally resuming at `resumeAt` seconds once the new page loads.
    func reloadVideo(videoId: String, resumeAt seconds: Double? = nil) {
        self.logger.info("Force-reloading YouTube video under new session identity: \(videoId)")
        self.pendingSeek = seconds
        self.load(videoId: videoId)
    }

    func cancelPendingLoad() {
        self.loadGeneration += 1
        self.webView?.stopLoading()
    }

    private func load(videoId: String) {
        guard let webView else {
            self.pendingVideoId = videoId
            self.currentVideoId = nil
            self.logger.info("Queued YouTube video until WebView exists: \(videoId)")
            return
        }

        self.logger.info("Loading YouTube video: \(videoId) (was: \(self.currentVideoId ?? "none"))")
        self.currentVideoId = videoId

        self.loadGeneration += 1
        let myLoadGeneration = self.loadGeneration

        let targetVolume = self.coordinator?.playerService.volume ?? 1.0
        self.installUserScripts(
            on: webView.configuration.userContentController,
            targetVolume: targetVolume,
            pendingSeek: self.pendingSeek
        )

        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else { return }
        webView.evaluateJavaScript("document.querySelector('video')?.pause()") { [weak self] _, _ in
            guard let self, let webView = self.webView else { return }
            guard myLoadGeneration == self.loadGeneration,
                  self.currentVideoId == videoId
            else {
                self.logger.debug("YouTube load superseded before navigation; skipping stale \(url.absoluteString)")
                return
            }
            webView.evaluateJavaScript("window.__optitubeTargetVolume = \(targetVolume);", completionHandler: nil)
            // Hide the WebView while the page paints its dark theme; it fades
            // back in once loaded and the transparency styles have applied.
            self.concealWebView()
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Anti-Flash Conceal/Reveal

    private func concealWebView() {
        guard let webView else { return }
        webView.alphaValue = 0
        self.concealGeneration += 1
        let generation = self.concealGeneration
        // Failsafe: never leave the player invisible if load callbacks are missed.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if generation == self.concealGeneration {
                self.revealWebView()
            }
        }
    }

    func revealWebView() {
        guard let webView, webView.alphaValue < 1 else { return }
        self.concealGeneration += 1
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            webView.animator().alphaValue = 1
        }
    }

    /// Stops playback and blanks the page.
    func tearDown() {
        guard let webView else { return }
        self.logger.info("Tearing down YouTube watch WebView")
        self.loadGeneration += 1
        self.currentVideoId = nil
        webView.evaluateJavaScript("document.querySelector('video')?.pause()") { _, _ in }
        webView.loadHTMLString("", baseURL: nil)
        webView.removeFromSuperview()
    }

    // MARK: - User Scripts

    private func installUserScripts(
        on contentController: WKUserContentController,
        targetVolume: Double,
        pendingSeek: Double? = nil
    ) {
        contentController.removeAllUserScripts()

        let bootstrap = WKUserScript(
            source: Self.pageBootstrapScript(targetVolume: targetVolume, pendingSeek: pendingSeek),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bootstrap)

        let observer = WKUserScript(
            source: Self.observerScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        // Inject at document start so the page never flashes an opaque background.
        let watchPageStyle = WKUserScript(
            source: Self.watchPageStyleScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(watchPageStyle)
        contentController.addUserScript(observer)
    }

    nonisolated static func pageBootstrapScript(targetVolume: Double, pendingSeek: Double? = nil) -> String {
        let clamped = targetVolume.isFinite ? min(max(targetVolume, 0), 1) : 1.0
        var script = "window.__optitubeTargetVolume = \(clamped);"
        if let pendingSeek, pendingSeek.isFinite, pendingSeek > 0 {
            script += " window.__optitubePendingSeek = \(pendingSeek);"
        }
        return script
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        let playerService: YouTubePlayerService

        init(playerService: YouTubePlayerService) {
            self.playerService = playerService
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            switch type {
            case "STATE_UPDATE":
                let update = YouTubePlayerService.PlaybackUpdate(
                    isPlaying: body["isPlaying"] as? Bool ?? false,
                    progress: body["progress"] as? Double ?? 0,
                    duration: body["duration"] as? Double ?? 0,
                    videoId: (body["videoId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                    title: body["title"] as? String,
                    isAd: body["isAd"] as? Bool ?? false
                )
                Task { @MainActor in
                    self.playerService.updatePlaybackState(update)
                }
            case "VIDEO_ENDED":
                let videoId = body["videoId"] as? String
                Task { @MainActor in
                    self.playerService.handleVideoEnded(videoId: videoId)
                }
            default:
                return
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            DiagnosticsLogger.player.info(
                "YouTube watch WebView finished loading: \(webView.url?.absoluteString ?? "nil")"
            )

            YouTubeWatchWebView.shared.pendingSeek = nil
            YouTubeWatchWebView.shared.revealWebView()

            let savedVolume = self.playerService.volume
            webView.evaluateJavaScript(
                """
                (function() {
                    window.__optitubeTargetVolume = \(savedVolume);
                    const video = document.querySelector('video');
                    if (video) { video.volume = \(savedVolume); }
                })();
                """,
                completionHandler: nil
            )
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            YouTubeWatchWebView.shared.revealWebView()
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            YouTubeWatchWebView.shared.revealWebView()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            YouTubeWatchWebView.shared.revealWebView()
            DiagnosticsLogger.player.error("YouTube watch WebView content process terminated, recovering")
            let videoId = YouTubeWatchWebView.shared.currentVideoId
            webView.reload()
            if let videoId {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    YouTubeWatchWebView.shared.currentVideoId = nil
                    YouTubeWatchWebView.shared.loadVideo(videoId: videoId)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith _: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures _: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            // Keep Google/YouTube auth flows inside the app's session;
            // open genuinely external links in the default browser.
            let host = url.host ?? ""
            if host.hasSuffix("google.com") || host.hasSuffix("youtube.com") {
                webView.load(navigationAction.request)
            } else {
                NSWorkspace.shared.open(url)
            }
            return nil
        }
    }
}

// MARK: - Scripts Extension

extension YouTubeWatchWebView {
    static var watchPageStyleScript: String {
        """
        (function() {
            const style = document.createElement('style');
            style.id = 'optitube-watch-style';
            style.textContent = `
                ytd-masthead,
                #masthead-container {
                    display: none !important;
                }
                /* html[dark] needed: YouTube defines its dark background vars on
                   html[dark], which outranks a bare html selector. */
                html[dark],
                html,
                body,
                ytd-app,
                #content,
                #page-manager,
                ytd-page-manager,
                ytd-watch-flexy,
                #columns,
                #primary,
                #primary-inner,
                #below,
                #secondary,
                #secondary-inner,
                #related,
                ytd-comments,
                ytd-item-section-renderer,
                #container.ytd-searchbox,
                #page-header-container,
                #page-header,
                #tabs-container,
                #tabs-inner-container,
                #chips-wrapper,
                .navigation-container,
                #cinematic-shorts-scrim,
                #shorts-container,
                tp-yt-app-drawer > #contentContainer,
                #guide-content,
                ytd-mini-guide-renderer,
                ytd-mini-guide-entry-renderer,
                .html5-main-video,
                .html5-video-container,
                #movie_player,
                #ytd-player,
                #player-container,
                #player-full-bleed-container,
                #full-bleed-container {
                    background-color: transparent !important;
                    background: none !important;
                }
                html[dark],
                html,
                body,
                ytd-app {
                    --yt-spec-base-background: transparent !important;
                    --yt-spec-brand-background-solid: transparent !important;
                    --yt-spec-general-background-a: transparent !important;
                    --yt-spec-general-background-b: transparent !important;
                    --yt-spec-general-background-c: transparent !important;
                }
                /* Ambient/cinematic canvases paint an opaque dark backdrop and
                   repaint constantly — removing them fixes the black background
                   AND makes scrolling much lighter. */
                #cinematics,
                #cinematic-container,
                #frosted-glass,
                #tabs-divider,
                .ytp-gradient-bottom,
                ytd-guide-signin-promo-renderer {
                    display: none !important;
                }
                body::-webkit-scrollbar {
                    display: none;
                }
                ytd-app {
                    --ytd-masthead-height: 0px !important;
                }
                #page-manager,
                ytd-page-manager {
                    margin-top: 0 !important;
                }
            `;
            if (document.documentElement) {
                document.documentElement.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    document.documentElement.appendChild(style);
                });
            }
        })();
        """
    }

    static var observerScript: String {
        """
        (function() {
            'use strict';

            const bridge = window.webkit.messageHandlers.youtubePlayer;
            let lastVideoId = '';

            function moviePlayer() {
                return document.getElementById('movie_player');
            }

            function videoEl() {
                return document.querySelector('#movie_player video') || document.querySelector('video');
            }

            function videoData() {
                const player = moviePlayer();
                if (player && typeof player.getVideoData === 'function') {
                    try { return player.getVideoData(); } catch (e) { return null; }
                }
                return null;
            }

            function currentVideoId() {
                const data = videoData();
                return (data && (data.video_id || data.videoId)) || '';
            }

            function currentTitle() {
                const data = videoData();
                if (data && data.title) { return data.title; }
                return document.title.replace(/ - YouTube$/, '');
            }

            function isAdShowing() {
                const player = moviePlayer();
                return !!(player && player.classList && player.classList.contains('ad-showing'));
            }

            function sendUpdate() {
                try {
                    const video = videoEl();
                    if (!video) { return; }
                    applyPendingSeek(video);
                    const videoId = currentVideoId();
                    if (videoId !== '') { lastVideoId = videoId; }
                    bridge.postMessage({
                        type: 'STATE_UPDATE',
                        isPlaying: !video.paused && !video.ended,
                        progress: video.currentTime || 0,
                        duration: (video.duration && isFinite(video.duration)) ? video.duration : 0,
                        videoId: videoId,
                        title: currentTitle(),
                        isAd: isAdShowing()
                    });
                } catch (e) {
                    console.log('[OptiTubeYT] update error: ' + e);
                }
            }

            function sendEnded() {
                bridge.postMessage({
                    type: 'VIDEO_ENDED',
                    videoId: lastVideoId || currentVideoId()
                });
            }

            function enforceVolume(video) {
                if (window.__optitubeIsSettingVolume) { return; }
                const target = window.__optitubeTargetVolume;
                if (typeof target === 'number' && target > 0 && video.muted) {
                    video.muted = false;
                    const player = moviePlayer();
                    if (player && typeof player.unMute === 'function') {
                        try { player.unMute(); } catch (e) {}
                    }
                }
                if (typeof target === 'number' && Math.abs(video.volume - target) > 0.01) {
                    window.__optitubeIsSettingVolume = true;
                    video.volume = target;
                    setTimeout(function() { window.__optitubeIsSettingVolume = false; }, 50);
                }
            }

            function applyPendingSeek(video) {
                const target = window.__optitubePendingSeek;
                if (typeof target !== 'number') { return; }
                if (isAdShowing()) { return; }
                if (video.readyState < 1) { return; }
                try {
                    video.currentTime = target;
                    setTimeout(function() {
                        if (typeof window.__optitubePendingSeek === 'number' &&
                            Math.abs(video.currentTime - target) > 1.5) {
                            try { video.currentTime = target; } catch (e) {}
                        }
                        window.__optitubePendingSeek = null;
                    }, 400);
                } catch (e) {}
            }

            // Belt-and-braces transparency: inline !important styles outrank
            // any stylesheet YouTube applies (html[dark] vars, theme swaps,
            // SPA re-renders), so the app's glass theme always shows through.
            var transparentSelectors = [
                'html', 'body', 'ytd-app', '#content', '#page-manager',
                'ytd-watch-flexy', '#columns', '#primary', '#primary-inner',
                '#below', '#secondary', '#secondary-inner', '#related',
                'ytd-comments', 'ytd-item-section-renderer',
                '#player-container', '#ytd-player', '#movie_player',
                '.html5-video-container', '#chips-wrapper',
                '#page-header-container', '#tabs-container'
            ];
            var hiddenSelectors = [
                '#cinematics', '#cinematic-container', '#frosted-glass',
                '.ytp-gradient-bottom'
            ];

            function enforceTransparency() {
                try {
                    transparentSelectors.forEach(function(sel) {
                        document.querySelectorAll(sel).forEach(function(el) {
                            el.style.setProperty('background-color', 'transparent', 'important');
                            el.style.setProperty('background-image', 'none', 'important');
                        });
                    });
                    hiddenSelectors.forEach(function(sel) {
                        document.querySelectorAll(sel).forEach(function(el) {
                            el.style.setProperty('display', 'none', 'important');
                        });
                    });
                } catch (e) {}
            }

            function disableAutonav() {
                try {
                    const toggle = document.querySelector('.ytp-autonav-toggle-button');
                    if (toggle && toggle.getAttribute('aria-checked') === 'true') {
                        toggle.click();
                        console.log('[OptiTubeYT] Disabled YouTube autonav');
                    }
                } catch (e) {}
            }

            function attach() {
                const video = videoEl();
                if (!video) { return; }
                if (video.__optitubeAttached) { return; }
                video.__optitubeAttached = true;

                ['play', 'playing', 'pause', 'seeked', 'loadedmetadata'].forEach(function(evt) {
                    video.addEventListener(evt, sendUpdate);
                });
                video.addEventListener('ended', sendEnded);
                video.addEventListener('volumechange', function() {
                    enforceVolume(video);
                });

                disableAutonav();
                enforceVolume(video);
                applyPendingSeek(video);
                sendUpdate();
            }

            setInterval(attach, 2000);
            setInterval(sendUpdate, 1000);
            setInterval(enforceTransparency, 1000);
            enforceTransparency();
            attach();
        })();
        """
    }
}

// MARK: - Playback Controls Extension

extension YouTubeWatchWebView {
    func playPause() {
        self.webView?.evaluateJavaScript(
            """
            (function() {
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (!video) { return 'no-video'; }
                if (video.paused) { video.play(); return 'playing'; } else { video.pause(); return 'paused'; }
            })();
            """,
            completionHandler: nil
        )
    }

    func play() {
        self.webView?.evaluateJavaScript(
            """
            (function() {
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (video && video.paused) { video.play(); }
            })();
            """,
            completionHandler: nil
        )
    }

    func pause() {
        self.webView?.evaluateJavaScript(
            """
            (function() {
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (video && !video.paused) { video.pause(); }
            })();
            """,
            completionHandler: nil
        )
    }

    func seek(to time: Double) {
        guard time.isFinite, time >= 0 else { return }
        self.webView?.evaluateJavaScript(
            """
            (function() {
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (video) { video.currentTime = \(time); }
            })();
            """,
            completionHandler: nil
        )
    }

    private func evaluateForString(_ script: String) async -> String? {
        guard let webView else { return nil }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, _ in
                continuation.resume(returning: result as? String)
            }
        }
    }

    static func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return json
    }

    func availableCaptionTracks() async -> [YouTubeCaptionTrack] {
        let script = """
        (function() {
            try {
                const player = document.getElementById('movie_player');
                if (!player || typeof player.getOption !== 'function') { return '[]'; }
                if (typeof player.loadModule === 'function') {
                    try { player.loadModule('captions'); } catch (e) {}
                }
                const tracks = player.getOption('captions', 'tracklist') || [];
                return JSON.stringify(tracks.map(function(track) {
                    return {
                        code: track.languageCode || '',
                        name: track.displayName || track.languageName || track.languageCode || ''
                    };
                }));
            } catch (e) { return '[]'; }
        })();
        """
        guard let json = await self.evaluateForString(script),
              let data = json.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else {
            return []
        }
        return entries.compactMap { entry in
            guard let code = entry["code"], !code.isEmpty,
                  let name = entry["name"], !name.isEmpty
            else {
                return nil
            }
            return YouTubeCaptionTrack(languageCode: code, displayName: name)
        }
    }

    func setCaptionTrack(languageCode: String?) {
        let script = if let languageCode {
            """
            (function() {
                const player = document.getElementById('movie_player');
                if (!player) { return; }
                try { player.loadModule('captions'); } catch (e) {}
                try { player.setOption('captions', 'track', {languageCode: '\(languageCode)'}); } catch (e) {}
            })();
            """
        } else {
            """
            (function() {
                const player = document.getElementById('movie_player');
                if (!player) { return; }
                try { player.setOption('captions', 'track', {}); } catch (e) {}
                try { player.unloadModule('captions'); } catch (e) {}
            })();
            """
        }
        self.webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func storyboardSpec(expectedVideoId: String?) async -> String? {
        let expectedLiteral = Self.jsStringLiteral(expectedVideoId ?? "")
        let script = """
        (function() {
            try {
                var expected = \(expectedLiteral);
                var response = null;
                var player = document.getElementById('movie_player');
                if (player && typeof player.getPlayerResponse === 'function') {
                    response = player.getPlayerResponse();
                }
                if (!response || !response.storyboards) {
                    response = window.ytInitialPlayerResponse;
                }
                if (!response || !response.storyboards) { return ''; }
                var details = response.videoDetails;
                var responseId = details && details.videoId;
                if (expected && responseId && responseId !== expected) { return ''; }
                var sb = response.storyboards;
                var renderer = sb.playerStoryboardSpecRenderer
                    || sb.playerLiveStoryboardSpecRenderer;
                return (renderer && renderer.spec) || '';
            } catch (e) { return ''; }
        })();
        """
        guard let spec = await self.evaluateForString(script), !spec.isEmpty else {
            return nil
        }
        return spec
    }

    func currentCaptionLanguageCode() async -> String? {
        let script = """
        (function() {
            try {
                const player = document.getElementById('movie_player');
                if (!player || typeof player.getOption !== 'function') { return ''; }
                const track = player.getOption('captions', 'track');
                return (track && track.languageCode) || '';
            } catch (e) { return ''; }
        })();
        """
        let code = await self.evaluateForString(script)
        return (code?.isEmpty == false) ? code : nil
    }

    func availableQualityLevels() async -> [String] {
        let script = """
        (function() {
            try {
                const player = document.getElementById('movie_player');
                if (!player || typeof player.getAvailableQualityLevels !== 'function') { return '[]'; }
                return JSON.stringify(player.getAvailableQualityLevels() || []);
            } catch (e) { return '[]'; }
        })();
        """
        guard let json = await self.evaluateForString(script),
              let data = json.data(using: .utf8),
              let levels = try? JSONSerialization.jsonObject(with: data) as? [String]
        else {
            return []
        }
        return levels
    }

    func currentQualityLevel() async -> String? {
        let script = """
        (function() {
            try {
                const player = document.getElementById('movie_player');
                if (!player || typeof player.getPlaybackQuality !== 'function') { return ''; }
                return player.getPlaybackQuality() || '';
            } catch (e) { return ''; }
        })();
        """
        let level = await self.evaluateForString(script)
        return (level?.isEmpty == false) ? level : nil
    }

    func setQualityLevel(_ level: String) {
        let script = """
        (function() {
            const player = document.getElementById('movie_player');
            if (!player) { return; }
            try { player.setPlaybackQualityRange('\(level)', '\(level)'); } catch (e) {
                try { player.setPlaybackQuality('\(level)'); } catch (e2) {}
            }
        })();
        """
        self.webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func showAirPlayPicker() {
        self.webView?.evaluateJavaScript(
            """
            (function() {
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (video && typeof video.webkitShowPlaybackTargetPicker === 'function') {
                    video.webkitShowPlaybackTargetPicker();
                }
            })();
            """,
            completionHandler: nil
        )
    }

    func setVolume(_ volume: Double) {
        let clamped = volume.isFinite ? min(max(volume, 0), 1) : 1.0
        self.webView?.evaluateJavaScript(
            """
            (function() {
                window.__optitubeTargetVolume = \(clamped);
                window.__optitubeIsSettingVolume = true;
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (video) {
                    video.volume = \(clamped);
                    if (\(clamped) > 0 && video.muted) { video.muted = false; }
                }
                const player = document.getElementById('movie_player');
                if (player && typeof player.setVolume === 'function') {
                    player.setVolume(\(Int((clamped * 100).rounded())));
                }
                if (player && \(clamped) > 0 && typeof player.unMute === 'function') {
                    try { player.unMute(); } catch (e) {}
                }
                setTimeout(function() { window.__optitubeIsSettingVolume = false; }, 100);
            })();
            """,
            completionHandler: nil
        )
    }
}

// MARK: - YouTubeWatchWebView + YouTubeWatchPlaybackControlling

extension YouTubeWatchWebView: YouTubeWatchPlaybackControlling {
    func prepare(webKitManager: WebKitManager, playerService: YouTubePlayerService) {
        _ = self.getWebView(webKitManager: webKitManager, playerService: playerService)
    }
}
