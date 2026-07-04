import SwiftUI

// MARK: - PersistentPlayerView

/// A SwiftUI view that displays the singleton WebView.
/// The WebView is created once and reused for all playback.
struct PersistentPlayerView: NSViewRepresentable {
    @Environment(WebKitManager.self) private var webKitManager
    @Environment(PlaybackStore.self) private var playbackStore

    let videoId: String
    let isExpanded: Bool

    private let logger = DiagnosticsLogger.player

    func makeNSView(context _: Context) -> NSView {
        self.logger.info("PersistentPlayerView.makeNSView for videoId: \(self.videoId)")

        let container = NSView(frame: .zero)
        container.wantsLayer = true

        // Get or create the singleton WebView
        let webView = SingletonPlayerWebView.shared.getWebView(
            webKitManager: self.webKitManager,
            playbackStore: self.playbackStore
        )

        // Remove from any previous superview and add to this container
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        // Load the video if needed - use loadVideo() to ensure volume is applied.
        // A restored session stays deferred until the user presses play,
        // otherwise the watch page autoplays the last track on launch.
        if !self.playbackStore.isPendingRestoredLoadDeferred,
           SingletonPlayerWebView.shared.currentVideoId != self.videoId {
            self.logger.info("Initial load for videoId: \(self.videoId)")
            SingletonPlayerWebView.shared.loadVideo(videoId: self.videoId)
        }

        return container
    }

    func updateNSView(_ container: NSView, context _: Context) {
        // Ensure WebView is in this container
        let webView = SingletonPlayerWebView.shared.getWebView(
            webKitManager: self.webKitManager,
            playbackStore: self.playbackStore
        )

        if webView.superview !== container {
            self.logger.info("Re-parenting WebView to current container")
            webView.removeFromSuperview()
            webView.frame = container.bounds
            webView.autoresizingMask = [.width, .height]
            container.addSubview(webView)
        }

        webView.frame = container.bounds

        // Load new video if changed (unless a restored session is deferred)
        if !self.playbackStore.isPendingRestoredLoadDeferred {
            SingletonPlayerWebView.shared.loadVideo(videoId: self.videoId)
        }
    }
}

// MARK: - MiniPlayerToast

/// A small toast-style view that appears when mini player is shown.
/// Uses Liquid Glass materialize transition for smooth appearance.
@available(macOS 15.0, *)
struct MiniPlayerToast: View {
    let videoId: String

    var body: some View {
        PersistentPlayerView(videoId: self.videoId, isExpanded: true)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .glassEffectTransition(.materialize)
    }
}
