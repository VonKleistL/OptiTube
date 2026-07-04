import AppKit
import Observation

/// Manages macOS haptic feedback (Trackpad) synchronized with music events.
@MainActor
@Observable
final class HapticManager {
    static let shared = HapticManager()
    
    private let logger = DiagnosticsLogger.player
    private let performer = NSHapticFeedbackManager.defaultPerformer
    
    private init() {}
    
    /// Triggers a haptic pulse on the trackpad.
    /// - Parameter pattern: The type of haptic feedback to perform.
    func triggerPulse(pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        guard SettingsManager.shared.hapticFeedbackEnabled else { return }
        
        // performer.perform(pattern, performanceTime: .now)
        // Note: NSHapticFeedbackManager is for UI interaction usually, 
        // but can be used for rhythm if called correctly.
        self.performer.perform(pattern, performanceTime: .now)
    }
}
