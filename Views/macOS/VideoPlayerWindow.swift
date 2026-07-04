import SwiftUI
import WebKit

// MARK: - VideoPlayerWindow

/// Floating window for video playback.
@available(macOS 15.0, *)
struct VideoPlayerWindow: View {
    @Environment(PlaybackStore.self) private var playbackStore

    var body: some View {
        // Video content (WebView container) with native HTML5 controls
        VideoWebViewContainer()
            .background(.black)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(minWidth: 320, minHeight: 180)
            .accessibilityIdentifier(AccessibilityID.VideoWindow.container)
    }
}

// MARK: - VideoWebViewContainer

/// NSViewRepresentable container for the video WebView.
@available(macOS 15.0, *)
struct VideoWebViewContainer: NSViewRepresentable {
    func makeNSView(context _: Context) -> VideoContainerView {
        DiagnosticsLogger.player.info("VideoWebViewContainer.makeNSView called")
        let container = VideoContainerView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        return container
    }

    func updateNSView(_ nsView: VideoContainerView, context _: Context) {
        DiagnosticsLogger.player.debug("VideoWebViewContainer.updateNSView called")
        // Reparent the WebView into this container for video display
        SingletonPlayerWebView.shared.ensureInHierarchy(container: nsView)
    }
}

// MARK: - VideoContainerView

/// Custom NSView that hosts the WebView and ensures it fills the container.
@available(macOS 15.0, *)
final class VideoContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        self.autoresizesSubviews = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        // Ensure the WebView follows our bounds immediately via native layout
        for subview in subviews {
            if subview is WKWebView {
                subview.frame = self.bounds
            }
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            // Re-sync video mode styles when window appears or moves
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                if SingletonPlayerWebView.shared.displayMode == .video {
                    SingletonPlayerWebView.shared.refreshVideoModeCSS()
                }
            }
        }
    }
}

// MARK: - Preview

@available(macOS 15.0, *)
#Preview {
    VideoPlayerWindow()
        .environment(PlaybackStore())
        .frame(width: 480, height: 270)
}
