import Foundation
import FoundationModels

/// AI-generated summary and analysis of track lyrics.
/// Provides themes, mood analysis, and an explanation of the track's meaning.
@available(macOS 15.0, *)
@Generable
struct LyricsSummary: Sendable {
    /// Key themes or topics in the lyrics (e.g., "love", "loss", "hope").
    @Guide(description: "List of 2-5 key themes or topics found in the lyrics.")
    let themes: [String]

    /// The overall mood or emotional tone of the track.
    @Guide(description: "A single word or short phrase describing the track's mood (e.g., 'melancholic', 'uplifting', 'nostalgic').")
    let mood: String

    /// A brief explanation of what the track is about.
    @Guide(description: "A concise explanation of the track's meaning and message (2-4 sentences). Be insightful but not overly academic.")
    let explanation: String
}
