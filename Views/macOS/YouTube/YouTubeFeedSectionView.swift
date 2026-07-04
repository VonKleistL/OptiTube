import SwiftUI

// MARK: - YouTubeFeedSectionView

/// Renders a single titled section from a YouTube feed with a lazy grid of item cards.
@available(macOS 15.0, *)
struct YouTubeFeedSectionView: View {
    let section: YouTubeFeedSection
    let onPlayVideo: (YouTubeVideo) -> Void
    var onOpenPlaylist: ((YouTubePlaylistItem) -> Void)?
    var onOpenChannel: ((YouTubeChannelItem) -> Void)?

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            LazyVGrid(columns: self.columns, spacing: 16) {
                ForEach(section.items) { item in
                    self.card(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func card(for item: YouTubeFeedItem) -> some View {
        switch item {
        case let .video(video):
            YouTubeVideoCard(video: video) {
                self.onPlayVideo(video)
            }

        case let .playlist(playlist):
            YouTubePlaylistCard(playlist: playlist, onTap: self.onOpenPlaylist)

        case let .channel(channel):
            YouTubeChannelCard(channel: channel, onTap: self.onOpenChannel)
        }
    }
}
