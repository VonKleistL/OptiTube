import AppKit
import SwiftUI

/// Manages the floating detachable mini-player window.
@available(macOS 15.0, *)
@MainActor
final class MiniPlayerWindowController {
    static let shared = MiniPlayerWindowController()
    
    private var window: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    
    private init() {}
    
    /// Shows the mini-player window.
    func show(playbackStore: PlaybackStore) {
        if let existingWindow = self.window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = MiniPlayerView()
            .environment(playbackStore)
            
        let hostingView = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hostingView
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating // Always on top
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        
        // Ensure resizability constraints
        panel.minSize = NSSize(width: 160, height: 160)
        panel.maxSize = NSSize(width: 800, height: 800)
        
        // Show the standard traffic light buttons even with hidden title bar
        panel.standardWindowButton(.closeButton)?.isHidden = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = false
        panel.standardWindowButton(.zoomButton)?.isHidden = false
        
        // Centered opening position (simplified)
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 240) / 2
            let y = (screen.frame.height - 240) / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.makeKeyAndOrderFront(nil)
        self.window = panel
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.windowWillClose),
            name: NSWindow.willCloseNotification,
            object: panel
        )
    }
    
    func close() {
        window?.close()
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        self.window = nil
        self.hostingView = nil
    }
}
