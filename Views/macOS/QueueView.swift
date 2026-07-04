import SwiftUI

// MARK: - QueueView

/// Right sidebar panel displaying the playback queue.
@available(macOS 15.0, *)
struct QueueView: View {
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(\.showCommandBar) private var showCommandBar

    /// Namespace for glass effect morphing.
    @Namespace private var queueNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                // Header
                self.headerView

                Divider()
                    .opacity(0.3)

                // Content
                self.contentView
            }
            .frame(width: 280)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .glassEffectID("queuePanel", in: self.queueNamespace)
        }
        .glassEffectTransition(.materialize)
        .accessibilityIdentifier(AccessibilityID.Queue.container)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Text(L("Up Next"))
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            // Auto-Pilot Toggle
            Button {
                withAnimation {
                    SettingsManager.shared.autoPilotEnabled.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text(L("Auto-Pilot"))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SettingsManager.shared.autoPilotEnabled ? Color.blue.opacity(0.2) : Color.primary.opacity(0.1))
                .clipShape(Capsule())
                .foregroundStyle(SettingsManager.shared.autoPilotEnabled ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help(L("Intelligent AI Queue"))

            // Clear queue button (only show if there are items beyond the current track)
            if self.playbackStore.queue.count > 1 {
                Button {
                    self.playbackStore.clearQueue()
                } label: {
                    Text(L("Clear"))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Queue.clearButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if self.playbackStore.queue.isEmpty {
            self.emptyQueueView
        } else {
            self.queueListView
        }
    }

    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(L("No Queue"))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L("Play tracks from a playlist or album to build your queue."))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.Queue.emptyState)
    }

    private var queueListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(self.playbackStore.queue.enumerated()), id: \.element.videoId) { index, track in
                    QueueRowView(
                        track: track,
                        isCurrentTrack: index == self.playbackStore.currentIndex,
                        index: index,
                        favoritesManager: self.favoritesManager,
                        playbackStore: self.playbackStore,
                        onRemove: {
                            self.playbackStore.removeFromQueue(videoIds: [track.videoId])
                        },
                        onTap: {
                            Task {
                                await self.playbackStore.playFromQueue(at: index)
                            }
                        }
                    )
                    .accessibilityIdentifier(AccessibilityID.Queue.row(index: index))
                }

                if SettingsManager.shared.autoPilotEnabled && !self.playbackStore.autoPilotTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L("AI Discoveries"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.blue.opacity(0.8))
                            
                            Spacer()
                            
                            if self.playbackStore.isFetchingAutoPilot {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        ForEach(self.playbackStore.autoPilotTracks) { track in
                            QueueRowView(
                                track: track,
                                isCurrentTrack: false,
                                index: -1, // No index for AI tracks
                                favoritesManager: self.favoritesManager,
                                playbackStore: self.playbackStore,
                                onRemove: { }, // Can't remove individual yet
                                onTap: {
                                    Task {
                                        // Manual selection of AI track moves it to real queue? 
                                        // For now just play it
                                        await self.playbackStore.play(track: track)
                                    }
                                }
                            )
                            .opacity(0.7)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier(AccessibilityID.Queue.scrollView)
    }
}

// MARK: - QueueRowView

@available(macOS 15.0, *)
private struct QueueRowView: View {
    let track: Track
    let isCurrentTrack: Bool
    let index: Int
    let favoritesManager: FavoritesManager
    let playbackStore: PlaybackStore
    let onRemove: () -> Void
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: self.onTap) {
            HStack(spacing: 12) {
                // Now Playing indicator or track number
                self.leadingIndicator
                    .frame(width: 24)

                // Thumbnail
                CachedAsyncImage(url: self.track.thumbnailURL?.highQualityThumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .overlay {
                            CassetteIcon(size: 16)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.track.title)
                        .font(.system(size: 13, weight: self.isCurrentTrack ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(self.isCurrentTrack ? .red : .primary)

                    Text(self.track.artistsDisplay.isEmpty ? "Unknown Artist" : self.track.artistsDisplay)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Duration
                if let duration = track.duration {
                    Text(self.formatDuration(duration))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(self.backgroundColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            self.isHovering = hovering
        }
        .contextMenu {
            FavoritesContextMenu.menuItem(for: self.track, manager: self.favoritesManager)

            Divider()

            StartRadioContextMenu.menuItem(for: self.track, playbackStore: self.playbackStore)

            Divider()

            ShareContextMenu.menuItem(for: self.track)

            if !self.isCurrentTrack {
                Button(role: .destructive) {
                    self.onRemove()
                } label: {
                    Label(L("Remove from Queue"), systemImage: "minus.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if self.isCurrentTrack {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.playbackStore.isPlaying ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                .symbolEffect(
                    .variableColor.iterative,
                    options: .repeating,
                    isActive: self.playbackStore.isPlaying
                )
        } else {
            Text("\(self.index + 1)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    private var backgroundColor: Color {
        if self.isCurrentTrack {
            return Color.red.opacity(0.1)
        } else if self.isHovering {
            return Color.primary.opacity(0.05)
        }
        return .clear
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

@available(macOS 15.0, *)
#Preview("Queue View") {
    let playbackStore = PlaybackStore()
    QueueView()
        .environment(playbackStore)
        .environment(FavoritesManager.shared)
        .frame(height: 600)
}

@available(macOS 15.0, *)
#Preview("Queue View with Items") {
    let playbackStore = PlaybackStore()
    // Note: In real use, queue would be populated via playQueue()
    QueueView()
        .environment(playbackStore)
        .environment(FavoritesManager.shared)
        .frame(height: 600)
}
