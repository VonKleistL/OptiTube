import SwiftUI
import WebKit

// MARK: - YouTubeWatchSurfaceView

/// Hosts the authenticated YouTube watch page inside a native view.
struct YouTubeWatchSurfaceView: NSViewRepresentable {
    @Environment(WebKitManager.self) private var webKitManager
    @Environment(YouTubePlayerService.self) private var youtubePlayer

    func makeNSView(context _: Context) -> YouTubeWatchContainerView {
        let container = YouTubeWatchContainerView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        return container
    }

    func updateNSView(_ nsView: YouTubeWatchContainerView, context _: Context) {
        _ = YouTubeWatchWebView.shared.getWebView(webKitManager: self.webKitManager, playerService: self.youtubePlayer)
        YouTubeWatchWebView.shared.ensureInHierarchy(container: nsView)
    }
}

// MARK: - YouTubeWatchContainerView

/// Custom NSView that keeps the WebView sized with the container.
final class YouTubeWatchContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.postsFrameChangedNotifications = true
        self.wantsLayer = true
        self.layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        for subview in self.subviews where subview is WKWebView {
            subview.frame = self.bounds
        }
    }
}
