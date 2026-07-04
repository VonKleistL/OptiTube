import SwiftUI
import WebKit

// MARK: - MiniPlayerWebView

/// A visible WebView that displays the YouTube Music player.
/// This is required because YouTube Music won't initialize the video player
/// without user interaction - autoplay is blocked in hidden WebViews.
/// Uses SingletonPlayerWebView for the actual WebView instance.
struct MiniPlayerWebView: NSViewRepresentable {
    @Environment(WebKitManager.self) private var webKitManager
    @Environment(PlaybackStore.self) private var playbackStore

    /// The video ID to play.
    let videoId: String

    /// Callback for player state changes.
    var onStateChange: ((PlayerState) -> Void)?

    /// Callback for metadata updates (title, artist, duration).
    var onMetadataChange: ((String, String, Double) -> Void)?

    enum PlayerState {
        case loading
        case playing
        case paused
        case ended
        case error(String)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: self.onStateChange, onMetadataChange: self.onMetadataChange)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true

        // Get or create the singleton WebView
        let webView = SingletonPlayerWebView.shared.getWebView(
            webKitManager: self.webKitManager,
            playbackStore: self.playbackStore
        )

        // Remove existing handler if present to avoid duplicates, then add fresh one
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: "miniPlayer")
        contentController.add(context.coordinator, name: "miniPlayer")

        // Ensure WebView is in this container
        SingletonPlayerWebView.shared.ensureInHierarchy(container: container)

        // Load the video if needed
        SingletonPlayerWebView.shared.loadVideo(videoId: self.videoId)

        return container
    }

    func updateNSView(_ container: NSView, context _: Context) {
        SingletonPlayerWebView.shared.ensureInHierarchy(container: container)
    }

    static func dismantleNSView(_: NSView, coordinator _: Coordinator) {
        SingletonPlayerWebView.shared.webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: "miniPlayer")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onStateChange: ((PlayerState) -> Void)?
        var onMetadataChange: ((String, String, Double) -> Void)?

        init(
            onStateChange: ((PlayerState) -> Void)?,
            onMetadataChange: ((String, String, Double) -> Void)?
        ) {
            self.onStateChange = onStateChange
            self.onMetadataChange = onMetadataChange
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {}

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            self.onStateChange?(.error(error.localizedDescription))
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            DiagnosticsLogger.player.error("MiniPlayer WebView content process terminated, attempting reload")
            self.onStateChange?(.error("Player crashed, reloading..."))
            webView.reload()
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            if type == "STATE_UPDATE" {
                let title = body["title"] as? String ?? ""
                let artist = body["artist"] as? String ?? ""
                let duration = body["duration"] as? Double ?? 0
                let isPlaying = body["isPlaying"] as? Bool ?? false

                if !title.isEmpty {
                    self.onMetadataChange?(title, artist, duration)
                }

                self.onStateChange?(isPlaying ? .playing : .paused)
            }
        }
    }
}
