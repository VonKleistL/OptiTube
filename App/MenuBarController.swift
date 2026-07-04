import AppKit
import SwiftUI
import Observation

/// Manages the macOS menu bar status item and popover.
@available(macOS 15.0, *)
@MainActor
final class MenuBarController {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var playbackStore: PlaybackStore?
    private weak var youtubePlayerService: YouTubePlayerService?

    private init() {}

    /// Initializes the menu bar presence.
    func setup(playbackStore: PlaybackStore, youtubePlayerService: YouTubePlayerService) {
        self.playbackStore = playbackStore
        self.youtubePlayerService = youtubePlayerService
        
        // Create Status Item
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Robust icon loading: try "App Icon" asset, fallback to system app icon
            let icon = NSImage(named: "App Icon") ?? NSApp.applicationIconImage
            icon?.isTemplate = false // Keep full color premium look
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.imagePosition = .imageOnly
            button.action = #selector(handleAction)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = statusItem
        
        // Setup Context Menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open OptiTube", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OptiTube", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = nil // Initially nil to let left-click work
        self.contextMenu = menu
        
        // Create Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 180)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarNowPlayingView()
                .environment(playbackStore)
                .environment(youtubePlayerService)
        )
        self.popover = popover
    }

    private var contextMenu: NSMenu?
    
    @objc private func handleAction() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            guard let button = self.statusItem?.button,
                  let event,
                  let contextMenu
            else { return }
            NSMenu.popUpContextMenu(contextMenu, with: event, for: button)
        } else {
            self.togglePopover()
        }
    }
    
    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }
    
    /// Updates the menu bar title based on playback state (strictly icon only per user request).
    func updateTitle(_ title: String?) {
        // Kept empty to ensure NO text is ever visible in the menu bar.
        statusItem?.button?.title = ""
    }
}
