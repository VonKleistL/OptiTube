import Foundation
import Observation
import CryptoKit

/// Service for scrobbling music playback to Last.fm.
@MainActor
@Observable
final class ScrobbleService {
    static let shared = ScrobbleService()
    
    private let logger = DiagnosticsLogger.auth
    private let apiKey = "8d184065e100f772591605658b163e79" // Mock API Key
    private let sharedSecret = "89704e6587deaf5cd685984687d6e5a6" // Mock Secret
    
    /// The currently playing track that is being tracked for scrobbling.
    private var activeTrack: Track?
    private var scrobbleStartTime: Date?
    private var hasScrobbledActiveTrack: Bool = false
    
    private init() {}
    
    /// Reports that a track has started playing (Now Playing).
    func trackStarted(_ track: Track) {
        guard SettingsManager.shared.scrobblingEnabled, SettingsManager.shared.lastFmSessionKey != nil else { return }
        
        self.activeTrack = track
        self.scrobbleStartTime = Date()
        self.hasScrobbledActiveTrack = false
        
        self.logger.info("ScrobbleService: Reporting Now Playing for \(track.title)")
        self.performApiCall(method: "track.updateNowPlaying", params: [
            "track": track.title,
            "artist": track.artistsDisplay,
            "album": track.album?.title ?? ""
        ])
    }
    
    /// Reports track progress to check if scrobble criteria is met.
    func updateProgress(progress: TimeInterval, duration: TimeInterval) {
        guard let track = activeTrack, !hasScrobbledActiveTrack else { return }
        guard SettingsManager.shared.scrobblingEnabled, SettingsManager.shared.lastFmSessionKey != nil else { return }
        
        // Last.fm criteria: 50% or 4 minutes
        let metCriteria = progress >= (duration / 2) || progress >= 240
        
        if metCriteria {
            self.hasScrobbledActiveTrack = true
            self.logger.info("ScrobbleService: Criteria met for \(track.title), queueing scrobble")
            
            self.performApiCall(method: "track.scrobble", params: [
                "track": track.title,
                "artist": track.artistsDisplay,
                "album": track.album?.title ?? "",
                "timestamp": String(Int(self.scrobbleStartTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970))
            ])
        }
    }
    
    // MARK: - Private API Support
    
    private func performApiCall(method: String, params: [String: String]) {
        guard let sessionKey = SettingsManager.shared.lastFmSessionKey else { return }
        
        var allParams = params
        allParams["method"] = method
        allParams["api_key"] = apiKey
        allParams["sk"] = sessionKey
        
        // Generate signature
        let signature = self.generateSignature(params: allParams)
        allParams["api_sig"] = signature
        allParams["format"] = "json"
        
        // In a real app, this would be a URLRequest.
        // For this demo, we'll log the API call simulation.
        self.logger.debug("ScrobbleService: Simulated API Call [\(method)] with signature \(signature)")
    }
    
    private func generateSignature(params: [String: String]) -> String {
        let sortedKeys = params.keys.sorted()
        var signatureString = ""
        for key in sortedKeys {
            signatureString += key + (params[key] ?? "")
        }
        signatureString += self.sharedSecret
        
        let data = Data(signatureString.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
