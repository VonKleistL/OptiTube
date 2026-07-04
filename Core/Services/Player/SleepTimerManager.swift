import Foundation
import Observation

/// Manages a sleep timer that stops playback after a specific duration with a gradual fade.
@MainActor
@Observable
final class SleepTimerManager {
    static let shared = SleepTimerManager()
    
    private let logger = DiagnosticsLogger.player
    private var timer: Timer?
    
    /// Remaining time in seconds.
    private(set) var remainingTime: TimeInterval?
    
    /// Whether a fade-out is currently in progress.
    private(set) var isFadingOut: Bool = false
    
    private init() {}
    
    /// Starts the sleep timer.
    /// - Parameter duration: Duration in seconds.
    func startTimer(duration: TimeInterval) {
        self.timer?.invalidate()
        self.remainingTime = duration
        self.isFadingOut = false
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        self.logger.info("SleepTimer: Started with duration \(duration)s")
    }
    
    /// Cancels the sleep timer.
    func cancelTimer() {
        self.timer?.invalidate()
        self.timer = nil
        self.remainingTime = nil
        self.isFadingOut = false
        self.logger.info("SleepTimer: Cancelled")
    }
    
    private func tick() {
        guard let current = self.remainingTime else { return }
        
        if current <= 0 {
            self.timerReachedZero()
            return
        }
        
        let next = current - 1
        self.remainingTime = next
        
        // Start gradual fade-out when 60 seconds remain
        if next <= 30 && !isFadingOut {
            self.startFadeOut()
        }
    }
    
    private func startFadeOut() {
        self.isFadingOut = true
        self.logger.info("SleepTimer: Starting 30s gradual fade-out")
        
        // We use the WebView's native fade if possible, or manual steps.
        // SingletonPlayerWebView.shared.fadeVolume(to: 0, durationMs: 30000)
        Task {
            SingletonPlayerWebView.shared.fadeVolume(to: 0, durationMs: 30000) {
                // Done fading
            }
        }
    }
    
    private func timerReachedZero() {
        self.timer?.invalidate()
        self.timer = nil
        self.remainingTime = nil
        self.isFadingOut = false
        
        self.logger.info("SleepTimer: Reached zero, stopping playback")
        Task {
            await PlaybackStore.shared?.stop()
        }
    }
}
