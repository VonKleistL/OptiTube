import Foundation
import Observation

/// Tracks playback history and user interactions to feed the Intelligent Queue engine.
@MainActor
@Observable
final class HistoryManager {
    static let shared = HistoryManager()
    
    private let logger = DiagnosticsLogger.auth // Reusing auth logger for now or create AI logger
    private let storageKey = "history.playbackEvents"
    private let maxHistoryLength = 200
    
    /// A single playback event representing a track interaction.
    struct PlaybackEvent: Codable, Sendable {
        let videoId: String
        let title: String
        let artistId: String?
        let albumId: String?
        let timestamp: Date
        let hourOfDay: Int
        let dayOfWeek: Int
        let durationWatched: TimeInterval
        let totalDuration: TimeInterval
        let wasSkipped: Bool
        
        var completionRate: Double {
            totalDuration > 0 ? durationWatched / totalDuration : 0
        }
    }
    
    /// recent playback history.
    private(set) var events: [PlaybackEvent] = []
    
    private init() {
        self.loadEvents()
    }
    
    /// Records a new playback event.
    func recordEvent(track: Track, durationWatched: TimeInterval, wasSkipped: Bool) {
        let calendar = Calendar.current
        let now = Date()
        
        // Extract IDs securely
        let artistId = track.artists.first?.id
        let albumId = track.album?.id
        
        let event = PlaybackEvent(
            videoId: track.videoId,
            title: track.title,
            artistId: artistId,
            albumId: albumId,
            timestamp: now,
            hourOfDay: calendar.component(.hour, from: now),
            dayOfWeek: calendar.component(.weekday, from: now),
            durationWatched: durationWatched,
            totalDuration: track.duration ?? 0,
            wasSkipped: wasSkipped
        )
        
        self.events.insert(event, at: 0)
        
        // Limit history length
        if self.events.count > self.maxHistoryLength {
            self.events = Array(self.events.prefix(self.maxHistoryLength))
        }
        
        self.saveEvents()
        self.logger.debug("HistoryManager: Recorded event for \(track.title) (skipped: \(wasSkipped))")
    }
    
    /// Returns the most frequent artists in the recent history.
    func getFrequentArtistIds(limit: Int = 10) -> [String] {
        let counts = Dictionary(grouping: events.compactMap(\.artistId), by: { $0 })
            .mapValues { $0.count }
        
        return counts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        do {
            let data = try JSONEncoder().encode(self.events)
            UserDefaults.standard.set(data, forKey: self.storageKey)
        } catch {
            self.logger.error("HistoryManager: Failed to save history: \(error.localizedDescription)")
        }
    }
    
    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: self.storageKey) else { return }
        
        do {
            self.events = try JSONDecoder().decode([PlaybackEvent].self, from: data)
            self.logger.info("HistoryManager: Loaded \(self.events.count) events")
        } catch {
            self.logger.error("HistoryManager: Failed to load history: \(error.localizedDescription)")
        }
    }
}
