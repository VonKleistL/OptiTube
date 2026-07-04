import Foundation
import Observation

/// Manages Discord Rich Presence for OptiTube.
@MainActor
@Observable
final class DiscordRPCManager {
    static let shared = DiscordRPCManager()
    
    private let logger = DiagnosticsLogger.auth
    private let clientID = "123456789012345678" // Mock Application ID
    
    /// The currently active activity being broadcast.
    private(set) var currentActivity: String?
    
    private init() {}
    
    /// Updates the Discord presence with the current track information.
    func updatePresence(track: Track, isPlaying: Bool, progress: TimeInterval) {
        guard SettingsManager.shared.discordRpcEnabled else {
            self.clearPresence()
            return
        }
        
        let state = track.artistsDisplay
        let details = track.title
        _ = isPlaying ? Date().addingTimeInterval(-progress) : nil
        
        // Log the simulated RPC update
        self.currentActivity = "\(details) by \(state)"
        self.logger.info("DiscordRPC: Updating presence to '\(self.currentActivity!)'")
        
        /*
         In a real implementation with a library:
         let activity = Activity()
         activity.state = state
         activity.details = details
         if let startTime = startTime {
            activity.timestamps.start = startTime
         }
         discordClient.updateActivity(activity)
         */
    }
    
    /// Clears the current Discord presence.
    func clearPresence() {
        if self.currentActivity != nil {
            self.logger.info("DiscordRPC: Clearing presence")
            self.currentActivity = nil
            // discordClient.clearActivity()
        }
    }
}
