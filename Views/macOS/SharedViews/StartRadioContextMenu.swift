import SwiftUI

// MARK: - StartRadioContextMenu

/// Shared context menu item for starting radio from a track.
@available(macOS 15.0, *)
@MainActor
enum StartRadioContextMenu {
    /// Creates a context menu button for starting radio based on a track.
    /// Starts playing the track immediately and loads similar tracks in the background.
    @ViewBuilder
    static func menuItem(for track: Track, playbackStore: PlaybackStore) -> some View {
        Button {
            Task {
                await playbackStore.playWithRadio(track: track)
            }
        } label: {
            Label("Start Radio", systemImage: "dot.radiowaves.left.and.right")
        }
    }
}
