import Foundation
import FoundationModels

/// A tool that provides the current playback queue context to the language model.
/// This allows AI to understand what's in the queue before making changes.
@available(macOS 15.0, *)
@MainActor
struct QueueTool: Tool {
    /// The PlaybackStore used to access queue state.
    private let playbackStore: PlaybackStore

    /// Logger for debugging.
    private let logger = DiagnosticsLogger.ai

    /// Creates a new QueueTool.
    /// - Parameter playbackStore: The PlaybackStore to access queue state from.
    init(playbackStore: PlaybackStore) {
        self.playbackStore = playbackStore
    }

    /// Human-readable name for the tool.
    let name = "getCurrentQueue"

    /// Description of what the tool does.
    let description = """
    Gets the current playback queue with track details.
    Use this to understand what's in the queue before making changes.
    Returns the current track, upcoming tracks, and queue length.
    """

    /// The arguments this tool accepts.
    @Generable
    struct Arguments: Sendable {
        @Guide(description: "Maximum number of tracks to return (default 20)")
        let limit: Int
    }

    /// Output type for the tool.
    typealias Output = String

    /// Returns the current queue state as a formatted string.
    nonisolated func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let queue = self.playbackStore.queue
            let currentIndex = self.playbackStore.currentIndex
            let limit = arguments.limit > 0 ? arguments.limit : 20

            guard !queue.isEmpty else {
                return "Queue is empty. No tracks are queued."
            }

            var output = "Current Queue (\(queue.count) tracks):\n"

            for (index, track) in queue.prefix(limit).enumerated() {
                let marker = index == currentIndex ? "▶ NOW PLAYING" : "  "
                output += "\(marker) \(index + 1). \"\(track.title)\" by \(track.artistsDisplay) [videoId: \(track.videoId)]\n"
            }

            if queue.count > limit {
                output += "... and \(queue.count - limit) more tracks"
            }

            self.logger.debug("QueueTool returned \(queue.count) tracks")
            return output
        }
    }
}
