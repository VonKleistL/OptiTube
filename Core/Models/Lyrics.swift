import Foundation

// MARK: - Lyrics

/// A single timed word for karaoke mode.
struct TimedWord: Sendable, Equatable {
    let timeInMs: Int
    let word: String
}

/// A single timed lyric line.
struct SyncedLyricLine: Sendable, Equatable, Identifiable {
    let id = UUID()
    /// Timestamp in milliseconds when this line starts.
    let timeInMs: Int
    /// Duration in milliseconds until next line.
    var duration: Int
    /// The lyric line text.
    let text: String
    /// Optional per-word timing.
    let words: [TimedWord]?
    /// Romanized version of the text.
    var romanizedText: String?
}

/// Synced lyrics model (line-based timestamps).
struct SyncedLyrics: Sendable, Equatable {
    let lines: [SyncedLyricLine]
    let source: String

    var isEmpty: Bool {
        self.lines.isEmpty
    }

    enum LineStatus {
        case previous
        case current
        case upcoming
    }

    func lineStatuses(at timeMs: Int) -> [LineStatus] {
        self.lines.map { line in
            if line.timeInMs > timeMs {
                return .upcoming
            }
            if timeMs - line.timeInMs >= line.duration, line.duration > 0 {
                return .previous
            }
            return .current
        }
    }

    func currentLineIndex(at timeMs: Int) -> Int? {
        self.lineStatuses(at: timeMs).lastIndex(of: .current)
    }
}

/// Unified lyrics result model with fallback ordering.
enum LyricResult: Sendable, Equatable {
    case synced(SyncedLyrics)
    case plain(Lyrics)
    case unavailable

    var isAvailable: Bool {
        switch self {
        case let .synced(synced):
            !synced.isEmpty
        case let .plain(plain):
            plain.isAvailable
        case .unavailable:
            false
        }
    }
}

/// Represents a single line of lyrics with a timestamp.
struct LyricLine: Sendable, Equatable, Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let text: String
}

/// Represents lyrics for a track from YouTube Music.
struct Lyrics: Sendable, Equatable {
    /// The lyrics lines with timestamps.
    let lines: [LyricLine]

    /// Source attribution (e.g., "Source: LyricFind").
    let source: String?

    /// Whether the track has lyrics available.
    var isAvailable: Bool { !self.lines.isEmpty }

    /// Returns the active lyric line for a given playback progress.
    func line(at progress: TimeInterval) -> LyricLine? {
        self.lines.last { $0.startTime <= progress }
    }

    /// Full lyrics text (all lines joined by newlines).
    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }

    /// Creates an empty lyrics instance for tracks without lyrics.
    static let unavailable = Lyrics(lines: [], source: nil)
}

// MARK: - LyricsBrowseInfo

/// Represents the lyrics browse ID extracted from the next endpoint.
struct LyricsBrowseInfo: Sendable {
    /// The browse ID to fetch lyrics (format: "MPLYt_xxx").
    let browseId: String
}
