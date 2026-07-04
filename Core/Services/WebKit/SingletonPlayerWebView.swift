import WebKit
import SwiftUI

// MARK: - SingletonPlayerWebView

/// Manages a single WebView instance for the entire app lifetime.
/// This ensures there's only ever ONE WebView playing audio.
@MainActor
final class SingletonPlayerWebView {
    static let shared = SingletonPlayerWebView()

    private(set) var webView: WKWebView?
    var currentVideoId: String?
    var coordinator: Coordinator?
    let logger = DiagnosticsLogger.player
    private var mediaControlUsesNextPrev: Bool

    enum DisplayMode {
        case hidden
        case miniPlayer
        case video
    }

    var displayMode: DisplayMode = .hidden

    private init() {
        self.mediaControlUsesNextPrev = SettingsManager.shared.mediaControlStyle == .nextPreviousTrack
    }

    func getWebView(
        webKitManager: WebKitManager,
        playbackStore: PlaybackStore
    ) -> WKWebView {
        if let existing = webView {
            return existing
        }

        self.coordinator = Coordinator(playbackStore: playbackStore)
        let configuration = webKitManager.createWebViewConfiguration()
        configuration.userContentController.add(self.coordinator!, name: "singletonPlayer")

        let mediaControlBootstrapScript = WKUserScript(
            source: self.mediaControlBootstrapScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(mediaControlBootstrapScript)

        let mediaOverrideScript = WKUserScript(
            source: Self.mediaControlOverrideScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(mediaOverrideScript)

        let script = WKUserScript(
            source: Self.observerScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(script)

        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.navigationDelegate = self.coordinator
        newWebView.customUserAgent = WebKitManager.userAgent

        #if DEBUG
            newWebView.isInspectable = true
        #endif

        self.webView = newWebView
        return newWebView
    }

    func ensureInHierarchy(container: NSView) {
        guard let webView else { return }
        
        // Only reparent if absolutely necessary
        if webView.superview !== container {
            webView.removeFromSuperview()
            container.addSubview(webView)
        }
        
        // Always ensure layout is correct
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        
        if webView.frame != container.bounds {
            webView.frame = container.bounds
        }
    }

    /// Starts high-frequency polling for synced lyrics time alignment.
    func startLyricsPoll() {
        self.webView?.evaluateJavaScript("if (window.startLyricsPoll) { window.startLyricsPoll(); }")
    }

    /// Stops high-frequency polling for synced lyrics time alignment.
    func stopLyricsPoll() {
        self.webView?.evaluateJavaScript("if (window.stopLyricsPoll) { window.stopLyricsPoll(); }")
    }

    func loadVideo(videoId: String) {
        guard let webView else { return }

        let previousVideoId = self.currentVideoId
        guard videoId != previousVideoId else { return }

        self.currentVideoId = videoId
        let currentVolume = self.coordinator?.playbackStore.volume ?? 1.0

        let urlToLoad = URL(string: "https://music.youtube.com/watch?v=\(videoId)")!
        webView.evaluateJavaScript("document.querySelector('video')?.pause()") { [weak self] _, _ in
            guard let self, let webView = self.webView else { return }
            let setTargetScript = "window.__optitubeTargetVolume = \(currentVolume);"
            webView.evaluateJavaScript(setTargetScript, completionHandler: nil)
            webView.load(URLRequest(url: urlToLoad))
        }
    }

    func reloadForAccountChange() {
        self.currentVideoId = nil
        self.webView?.reload()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let playbackStore: PlaybackStore

        init(playbackStore: PlaybackStore) {
            self.playbackStore = playbackStore
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            let observedVideoId: String? = if let videoId = body["videoId"] as? String, !videoId.isEmpty {
                videoId
            } else {
                nil
            }

            if type == "TRACK_ENDED" {
                Task { @MainActor in
                    await self.playbackStore.handleTrackEnded(observedVideoId: observedVideoId)
                }
                return
            }

            if type == "REMOTE_NEXT" {
                Task { @MainActor in
                    await self.playbackStore.next()
                }
                return
            }

            if type == "REMOTE_PREVIOUS" {
                Task { @MainActor in
                    await self.playbackStore.previous()
                }
                return
            }

            if type == "AIRPLAY_STATUS" {
                let isConnected = body["isConnected"] as? Bool ?? false
                let wasRequested = body["wasRequested"] as? Bool ?? false
                Task { @MainActor in
                    self.playbackStore.updateAirPlayStatus(isConnected: isConnected, wasRequested: wasRequested)
                }
                return
            }
            
            if type == "HAPTIC_PEAK" {
                Task { @MainActor in
                    HapticManager.shared.triggerPulse(pattern: .generic)
                }
                return
            }

            if type == "VIDEO_DETECTED" {
                Task { @MainActor in
                    SingletonPlayerWebView.shared.setupEQ()
                }
                return
            }

            if type == "LYRICS_TIME" {
                if let time = body["time"] as? Double {
                    Task { @MainActor in
                        self.playbackStore.currentTimeMs = Int(time * 1000)
                    }
                }
                return
            }

            guard type == "STATE_UPDATE" else { return }

            let isPlaying = body["isPlaying"] as? Bool ?? false
            let progress = body["progress"] as? Int ?? 0
            let duration = body["duration"] as? Int ?? 0
            let title = body["title"] as? String ?? ""
            let artist = body["artist"] as? String ?? ""
            let thumbnailUrl = body["thumbnailUrl"] as? String ?? ""
            let trackChanged = body["trackChanged"] as? Bool ?? false
            let likeStatusString = body["likeStatus"] as? String ?? "INDIFFERENT"
            let hasVideo = body["hasVideo"] as? Bool ?? false

            let likeStatus: LikeStatus = switch likeStatusString {
            case "LIKE": .like
            case "DISLIKE": .dislike
            default: .indifferent
            }

            Task { @MainActor in
                self.playbackStore.updatePlaybackState(isPlaying: isPlaying, progress: Double(progress), duration: Double(duration))
                self.playbackStore.updateVideoAvailability(hasVideo: hasVideo)
                if trackChanged { self.playbackStore.updateLikeStatus(likeStatus) }
                let shouldReconcileMetadata = (trackChanged || self.playbackStore.repeatMode == .one) && (observedVideoId != nil || !title.isEmpty)
                if shouldReconcileMetadata {
                    self.playbackStore.updateTrackMetadata(
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                        videoId: observedVideoId
                    )
                    if self.playbackStore.showVideo, !self.playbackStore.isVideoGracePeriodActive {
                        self.playbackStore.showVideo = false
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            SingletonPlayerWebView.shared.setupEQ()
            SingletonPlayerWebView.shared.enableHaptics(SettingsManager.shared.hapticFeedbackEnabled)

            let savedVolume = self.playbackStore.volume
            let applyVolumeScript = """
                (function() {
                    window.__optitubeTargetVolume = \(savedVolume);
                    window.__optitubeIsSettingVolume = true;
                    const video = document.querySelector('video');
                    if (video) video.volume = \(savedVolume);
                    setTimeout(() => { window.__optitubeIsSettingVolume = false; }, 100);
                    return video ? 'applied' : 'no-video-yet';
                })();
            """
            webView.evaluateJavaScript(applyVolumeScript, completionHandler: nil)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            let currentVideoId = SingletonPlayerWebView.shared.currentVideoId
            webView.reload()
            if let videoId = currentVideoId {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    SingletonPlayerWebView.shared.currentVideoId = nil
                    SingletonPlayerWebView.shared.loadVideo(videoId: videoId)
                }
            }
        }
    }
}

// MARK: - SingletonPlayerWebView Media Controls

extension SingletonPlayerWebView {
    /// Updates the page and bootstrap state used by future loads.
    func setMediaControlStyle(useNextPrev: Bool) {
        self.mediaControlUsesNextPrev = useNextPrev
        guard let webView = self.webView else { return }
        webView.evaluateJavaScript(Self.mediaControlStyleSyncScript(useNextPrev: useNextPrev), completionHandler: nil)
    }

    private func mediaControlBootstrapScript() -> String {
        Self.mediaControlStyleBootstrapScript(useNextPrev: self.mediaControlUsesNextPrev)
    }

    private static func mediaControlStyleBootstrapScript(useNextPrev: Bool) -> String {
        let jsBoolean = useNextPrev ? "true" : "false"
        return """
            (function() {
                try {
                    localStorage.setItem('optitubeUseNextPrev', '\(jsBoolean)');
                } catch (e) {}
                window.__optitubeUseNextPrev = \(jsBoolean);
            })();
        """
    }

    private static func mediaControlStyleSyncScript(useNextPrev: Bool) -> String {
        let jsBoolean = useNextPrev ? "true" : "false"
        let restoreSeekHandlers = if useNextPrev {
            ""
        } else {
            """
                try {
                    var ms = navigator.mediaSession;
                    ms.setActionHandler('nexttrack', null);
                    ms.setActionHandler('previoustrack', null);
                    ms.setActionHandler('seekforward', function(d) {
                        var v = document.querySelector('video');
                        if (v) v.currentTime = Math.min(v.duration, v.currentTime + ((d && d.seekOffset) || 15));
                    });
                    ms.setActionHandler('seekbackward', function(d) {
                        var v = document.querySelector('video');
                        if (v) v.currentTime = Math.max(0, v.currentTime - ((d && d.seekOffset) || 15));
                    });
                } catch (e) {}
            """
        }

        return """
            (function() {
                try {
                    localStorage.setItem('optitubeUseNextPrev', '\(jsBoolean)');
                } catch (e) {}
                window.__optitubeUseNextPrev = \(jsBoolean);
                if (typeof window.__optitubeRefreshMediaControlStyle === 'function') {
                    window.__optitubeRefreshMediaControlStyle();
                }
                \(restoreSeekHandlers)
            })();
        """
    }

    private static var mediaControlOverrideScript: String {
        """
        (function() {
            if (typeof window.__optitubeUseNextPrev !== 'boolean') {
                try {
                    window.__optitubeUseNextPrev = localStorage.getItem('optitubeUseNextPrev') === 'true';
                } catch (e) {
                    window.__optitubeUseNextPrev = false;
                }
            }

            var overrideFrameId = null;

            function applyOverride() {
                if (!window.__optitubeUseNextPrev) {
                    return;
                }
                try {
                    var ms = navigator.mediaSession;
                    ms.setActionHandler('seekforward', null);
                    ms.setActionHandler('seekbackward', null);
                    ms.setActionHandler('nexttrack', function() {
                        window.webkit.messageHandlers.singletonPlayer.postMessage({ type: 'REMOTE_NEXT' });
                    });
                    ms.setActionHandler('previoustrack', function() {
                        window.webkit.messageHandlers.singletonPlayer.postMessage({ type: 'REMOTE_PREVIOUS' });
                    });
                } catch (e) {}
            }

            function scheduleOverrideLoop() {
                if (overrideFrameId !== null || !window.__optitubeUseNextPrev) {
                    return;
                }

                overrideFrameId = requestAnimationFrame(function() {
                    overrideFrameId = null;
                    if (!window.__optitubeUseNextPrev) {
                        return;
                    }
                    applyOverride();
                    scheduleOverrideLoop();
                });
            }

            window.__optitubeRefreshMediaControlStyle = function() {
                applyOverride();
                scheduleOverrideLoop();
            };

            window.__optitubeRefreshMediaControlStyle();

            function attachVideoOverride() {
                var v = document.querySelector('video');
                if (!v || v.__optitubeOverrideAttached) return;
                v.__optitubeOverrideAttached = true;
                ['playing','loadedmetadata','loadeddata','canplay','seeked']
                    .forEach(function(e) { v.addEventListener(e, applyOverride); });
            }

            attachVideoOverride();
            new MutationObserver(attachVideoOverride)
                .observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
    }
}
