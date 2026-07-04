import Foundation
import Observation

/// A machine learning-powered recommendation engine for predictive queueing.
///
/// Use local heuristics and statistical analysis (mimicking CoreML regressor behavior)
/// to suggest the next track based on user history and context.
@MainActor
@Observable
final class QueuePredictor {
    static let shared = QueuePredictor()
    
    private let logger = DiagnosticsLogger.player
    private let historyManager = HistoryManager.shared
    
    private init() {}
    
    /// Predicts the "best" next tracks from a list of candidates.
    ///
    /// - Parameters:
    ///   - candidates: A list of tracks to choose from (e.g. Related tracks from API).
    ///   - limit: Maximum number of tracks to return.
    /// - Returns: Ranked list of suggested tracks.
    func rankCandidates(_ candidates: [Track], limit: Int = 3) -> [Track] {
        guard !candidates.isEmpty else { return [] }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        typealias ScoredTrack = (track: Track, score: Double)
        var scoredTracks: [ScoredTrack] = []
        
        // Frequent artists for boost
        let frequentArtists = Set(historyManager.getFrequentArtistIds(limit: 5))
        
        for track in candidates {
            var score: Double = 1.0 // Base score
            
            // 1. Boost if it's a frequent artist
            if let primaryArtistId = track.artists.first?.id, frequentArtists.contains(primaryArtistId) {
                score *= 1.5
            }
            
            // 2. Contextual analysis (Historical preference for this artist at this time)
            let historicalMatches = historyManager.events.filter { event in
                event.artistId == track.artists.first?.id &&
                abs(event.hourOfDay - currentHour) <= 2
            }
            
            if !historicalMatches.isEmpty {
                let matchBoost = 1.0 + (Double(historicalMatches.count) * 0.1)
                score *= min(matchBoost, 2.0)
            }
            
            // 3. Penalty for recently skipped tracks
            let skipCount = historyManager.events.filter { $0.videoId == track.videoId && $0.wasSkipped }.count
            if skipCount > 0 {
                score *= pow(0.5, Double(skipCount))
            }
            
            // 4. Boost for tracks that are usually completed
            let completionStats = historyManager.events.filter { $0.videoId == track.videoId && !$0.wasSkipped }
            if !completionStats.isEmpty {
                score *= 1.2
            }
            
            scoredTracks.append((track, score))
        }
        
        // Sort by score descending and return top matches
        return scoredTracks.sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.track }
    }
}
