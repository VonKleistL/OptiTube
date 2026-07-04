import SwiftUI

// MARK: - YouTubeVideoCard

/// Glass-style card for a single YouTube video result in a feed or search results grid.
@available(macOS 15.0, *)
struct YouTubeVideoCard: View {
    let video: YouTubeVideo
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: self.onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    self.thumbnail

                    // Duration badge
                    if let duration = video.lengthText, !video.isLive {
                        Text(duration)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }

                    // Live badge
                    if video.isLive {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }

                    // Shorts badge
                    if video.isShort {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.6), in: Circle())
                            .padding(6)
                    }
                }

                // Watched progress bar
                if let watchedPercent = video.watchedPercent, watchedPercent > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.white.opacity(0.2))
                                .frame(height: 3)
                            Rectangle()
                                .fill(Color.appAccent)
                                .frame(width: geo.size.width * CGFloat(watchedPercent) / 100.0, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 10)
                }

                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let channel = video.channelName {
                        Text(channel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Views + date
                    let meta = [video.viewCountText, video.publishedText]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .background(
                GlassTokens.panelTint,
                in: RoundedRectangle(cornerRadius: GlassTokens.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: GlassTokens.cornerRadius, style: .continuous)
                    .stroke(GlassTokens.stroke, lineWidth: 1)
            }
            // Shadow only on hover: constant per-card shadows make feed scrolling heavy.
            .shadow(
                color: self.isHovered ? GlassTokens.shadow : .clear,
                radius: self.isHovered ? 18 : 0,
                x: 0, y: self.isHovered ? 10 : 0
            )
            .scaleEffect(self.isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: self.isHovered)
        .accessibilityLabel(video.title)
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .aspectRatio(16 / 9, contentMode: .fit)

            if let url = video.thumbnailURL {
                CachedAsyncImage(url: url, targetSize: CGSize(width: 640, height: 360)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - YouTubeChannelCard

@available(macOS 15.0, *)
struct YouTubeChannelCard: View {
    let channel: YouTubeChannelItem
    var onTap: ((YouTubeChannelItem) -> Void)?

    var body: some View {
        if let onTap {
            Button {
                onTap(self.channel)
            } label: {
                self.cardBody
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.channel.name)
        } else {
            self.cardBody
        }
    }

    private var cardBody: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: channel.thumbnailURL, targetSize: CGSize(width: 144, height: 144)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(GlassTokens.stroke, lineWidth: 1))

            Text(channel.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let subs = channel.subscriberCountText {
                Text(subs)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            GlassTokens.panelTint,
            in: RoundedRectangle(cornerRadius: GlassTokens.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GlassTokens.cornerRadius, style: .continuous)
                .stroke(GlassTokens.stroke, lineWidth: 1)
        }
    }
}

// MARK: - YouTubePlaylistCard

@available(macOS 15.0, *)
struct YouTubePlaylistCard: View {
    let playlist: YouTubePlaylistItem
    var onTap: ((YouTubePlaylistItem) -> Void)?

    var body: some View {
        if let onTap {
            Button {
                onTap(self.playlist)
            } label: {
                self.cardBody
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.playlist.title)
        } else {
            self.cardBody
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.thumbnailURL, targetSize: CGSize(width: 640, height: 360)) { image in
                    image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .aspectRatio(16 / 9, contentMode: .fit)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let count = playlist.videoCount {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 9))
                        Text(count)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                    .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)

                if let channel = playlist.channelName {
                    Text(channel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(
            GlassTokens.panelTint,
            in: RoundedRectangle(cornerRadius: GlassTokens.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GlassTokens.cornerRadius, style: .continuous)
                .stroke(GlassTokens.stroke, lineWidth: 1)
        }
    }
}
