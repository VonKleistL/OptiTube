import AppKit
import Foundation

/// Manages custom keyboard shortcuts and handles key events.
@MainActor
final class ShortcutManager {
    static let shared = ShortcutManager()
    
    private let logger = DiagnosticsLogger.auth
    private var localMonitor: Any?
    
    private init() {}
    
    /// Starts monitoring for keyboard shortcuts.
    func startMonitoring() {
        self.stopMonitoring()
        
        self.localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleShortcut(event) == true {
                return nil // Consume event
            }
            return event
        }
        
        self.logger.info("ShortcutManager: Started monitoring")
    }
    
    /// Stops monitoring.
    func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    /// Handles a key down event and executes the associated action if it matches a custom shortcut.
    /// - Returns: True if a shortcut was handled.
    private func handleShortcut(_ event: NSEvent) -> Bool {
        let shortcuts = SettingsManager.shared.customShortcuts
        guard !shortcuts.isEmpty else { return false }
        
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        for shortcut in shortcuts {
            if shortcut.keyCode == keyCode && shortcut.modifiers == modifiers {
                self.executeAction(shortcut.actionIdentifier)
                return true
            }
        }
        
        return false
    }
    
    /// Executes the action associated with the shortcut identifier.
    private func executeAction(_ identifier: String) {
        self.logger.info("ShortcutManager: Executing action \(identifier)")
        
        Task {
            switch identifier {
            case "playback.playPause":
                await PlaybackStore.shared?.playPause()
            case "playback.next":
                await PlaybackStore.shared?.next()
            case "playback.previous":
                await PlaybackStore.shared?.previous()
            case "playback.volumeUp":
                if let store = PlaybackStore.shared {
                    await store.setVolume(min(1.0, store.volume + 0.05))
                }
            case "playback.volumeDown":
                if let store = PlaybackStore.shared {
                    await store.setVolume(max(0.0, store.volume - 0.05))
                }
            default:
                break
            }
        }
    }
}
