import SwiftUI

/// A compact view for the system menu bar popover.
/// Follows the active app source: music playback or the YouTube video player.
@available(macOS 15.0, *)
struct MenuBarNowPlayingView: View {
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(YouTubePlayerService.self) private var youtubePlayer

    /// YouTube mode is shown when the app is in the video source and a video is loaded.
    private var showsYouTube: Bool {
        SettingsManager.shared.appSource != .music && self.youtubePlayer.currentVideo != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            if self.showsYouTube {
                self.youtubeContent
            } else {
                self.musicContent
            }

            Divider()

            Button {
                // Focus main window
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Open OptiTube", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 260)
        .background(.background)
    }

    // MARK: - Music Mode

    @ViewBuilder
    private var musicContent: some View {
        HStack(spacing: 12) {
            // Compact Artwork
            if let track = playbackStore.currentTrack {
                CachedAsyncImage(url: track.thumbnailURL?.highQualityThumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playbackStore.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(playbackStore.currentTrack?.artistsDisplay ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }

        Divider()

        // Playback Controls
        HStack(spacing: 20) {
            Button {
                Task { await playbackStore.previous() }
            } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.pressable)

            Button {
                Task { await playbackStore.playPause() }
            } label: {
                Image(systemName: playbackStore.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.pressable)

            Button {
                Task { await playbackStore.next() }
            } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.pressable)

            AirPlayPickerView()
                .frame(width: 24, height: 24)
        }
        .padding(.bottom, 4)
    }

    // MARK: - YouTube Mode

    @ViewBuilder
    private var youtubeContent: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: self.youtubePlayer.currentVideo?.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(self.youtubePlayer.currentVideo?.title ?? "Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if let channel = self.youtubePlayer.currentVideo?.channelName {
                    Text(channel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }

        Divider()

        HStack(spacing: 20) {
            Button {
                YouTubeWatchWebView.shared.playPause()
            } label: {
                Image(systemName: self.youtubePlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.pressable)
        }
        .padding(.bottom, 4)
    }
}
