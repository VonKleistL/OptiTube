import SwiftUI

// MARK: - PlayerBar

/// Player bar shown at the bottom of the content area, styled like Apple Music with Liquid Glass.
@available(macOS 15.0, *)
struct PlayerBar: View {
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(WebKitManager.self) private var webKitManager

    /// Namespace for glass effect morphing and unioning.
    @Namespace private var playerNamespace

    @State private var isHovering = false

    /// Local seek value for smooth slider dragging without network calls on every change.
    @State private var seekValue: Double = 0
    @State private var isSeeking = false

    /// Local volume value for smooth slider dragging.
    @State private var volumeValue: Double = 1.0
    @State private var isAdjustingVolume = false

    /// Cached formatted progress string to avoid repeated formatting.
    @State private var formattedProgress: String = "0:00"
    @State private var formattedRemaining: String = "-0:00"
    /// Last integer second of progress to reduce string formatting frequency.
    @State private var lastProgressSecond: Int = -1

    /// State to control EQ popover visibility.
    @State private var showEqualizer: Bool = false
    
    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                // Left section: Playback controls
                self.playbackControls

                Spacer()

                // Center section: Track info OR seek bar (on hover)
                self.centerSection

                Spacer()

                // Right section: Volume control
                self.volumeControl
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(height: 52)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID("playerBar", in: self.playerNamespace)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        .onChange(of: self.playbackStore.progress) { _, newValue in
            // Sync local seek value when not actively seeking
            if !self.isSeeking, self.playbackStore.duration > 0 {
                self.seekValue = newValue / self.playbackStore.duration
            }
            // Only update formatted strings when the second changes to reduce Text view updates
            let currentSecond = Int(newValue)
            if currentSecond != self.lastProgressSecond {
                self.lastProgressSecond = currentSecond
                self.formattedProgress = self.formatTime(newValue)
                self.formattedRemaining = "-\(self.formatTime(self.playbackStore.duration - newValue))"
            }
        }
        .onChange(of: self.playbackStore.volume) { _, newValue in
            // Sync local volume value when not actively adjusting
            if !self.isAdjustingVolume {
                self.volumeValue = newValue
            }
        }
        .onAppear {
            // Sync local volume value from saved state on initial load
            self.volumeValue = self.playbackStore.volume
        }
    }

    // MARK: - Center Section (track info blurs, seek bar appears on hover)

    private var centerSection: some View {
        ZStack {
            // Error state display with retry option
            if case let .error(message) = playbackStore.state {
                self.errorView(message: message)
            } else {
                // Track info (blurred when hovering and track is playing)
                self.trackInfoView
                    .blur(radius: self.isHovering && self.playbackStore.currentTrack != nil ? 8 : 0)
                    .opacity(self.isHovering && self.playbackStore.currentTrack != nil ? 0 : 1)

                // Seek bar (shown when hovering and track is playing)
                if self.isHovering, self.playbackStore.currentTrack != nil {
                    self.seekBarView
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: 400)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))

            Text(message)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    if let track = playbackStore.currentTrack {
                        await self.playbackStore.play(track: track)
                    }
                }
            } label: {
                Text(L("Retry"))
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(.capsule)
        }
    }

    // MARK: - Track Info View

    private var trackInfoView: some View {
        HStack(spacing: 12) {
            // Thumbnail with transition animation
            ZStack {
                CachedAsyncImage(url: self.playbackStore.currentTrack?.thumbnailURL?.highQualityThumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .overlay {
                            CassetteIcon(size: 20)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .id(self.playbackStore.currentTrack?.videoId) // Trigger animation on track change
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: self.playbackStore.currentTrack?.videoId)

            // Track info with staggered text entry
            if let track = playbackStore.currentTrack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))

                    Text(track.artistsDisplay.isEmpty ? L("Unknown Artist") : track.artistsDisplay)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring.delay(0.05)), removal: .move(edge: .top).combined(with: .opacity)))
                }
                .frame(maxWidth: 220, alignment: .leading)
                .id("info-\(track.videoId)") // Staggered transition
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: self.playbackStore.currentTrack?.videoId)
    }

    // MARK: - Seek Bar View (replaces track info on hover)

    private var seekBarView: some View {
        HStack(spacing: 10) {
            // Elapsed time - use cached formatted string when not seeking
            Text(self.isSeeking ? self.formatTime(self.seekValue * self.playbackStore.duration) : self.formattedProgress)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(minWidth: 45, alignment: .trailing)
                .monospacedDigit()

            // Seek slider
            Slider(value: self.$seekValue, in: 0 ... 1) { editing in
                if editing {
                    // User started dragging
                    self.isSeeking = true
                } else {
                    // User finished dragging - perform seek
                    self.performSeek()
                }
            }
            .controlSize(.small)

            // Remaining time - use cached formatted string when not seeking
            Text(self.isSeeking ? "-\(self.formatTime(self.playbackStore.duration - self.seekValue * self.playbackStore.duration))" : self.formattedRemaining)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(minWidth: 45, alignment: .leading)
                .monospacedDigit()
        }
    }

    /// Performs the actual seek operation after slider interaction ends.
    private func performSeek() {
        guard self.isSeeking else { return }
        let seekTime = self.seekValue * self.playbackStore.duration
        Task {
            await self.playbackStore.seek(to: seekTime)
            self.isSeeking = false
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Shuffle
            Button {
                HapticService.toggle()
                self.playbackStore.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playbackStore.shuffleEnabled ? .appAccent : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L("Shuffle"))
            .accessibilityValue(self.playbackStore.shuffleEnabled ? L("On") : L("Off"))

            // Previous
            Button {
                HapticService.playback()
                Task {
                    await self.playbackStore.previous()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L("Previous track"))

            // Play/Pause
            Button {
                HapticService.playback()
                Task {
                    await self.playbackStore.playPause()
                }
            } label: {
                Image(systemName: self.playbackStore.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .glassEffectID("playPause", in: self.playerNamespace)
            .accessibilityLabel(self.playbackStore.isPlaying ? L("Pause") : L("Play"))

            // Next
            Button {
                HapticService.playback()
                Task {
                    await self.playbackStore.next()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L("Next track"))

            // Repeat
            Button {
                HapticService.toggle()
                self.playbackStore.cycleRepeatMode()
            } label: {
                Image(systemName: self.repeatIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playbackStore.repeatMode != .off ? .appAccent : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L("Repeat"))
            .accessibilityValue(self.repeatAccessibilityValue)
        }
    }

    private var repeatIcon: String {
        switch self.playbackStore.repeatMode {
        case .off, .all:
            "repeat"
        case .one:
            "repeat.1"
        }
    }

    private var repeatAccessibilityValue: String {
        switch self.playbackStore.repeatMode {
        case .off:
            L("Off")
        case .all:
            L("All")
        case .one:
            L("One")
        }
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        @Bindable var player = self.playbackStore
        
        return HStack(spacing: 8) {
            // Like/Dislike/Library actions
            self.actionButtons


            // EQ button
            Button {
                self.showEqualizer.toggle()
            } label: {
                Image(systemName: "slider.vertical.3")
                    .foregroundStyle(self.showEqualizer ? .appAccent : .primary)
            }
            .buttonStyle(.pressable)
            .help(L("Audio Equalizer"))
            .popover(isPresented: $showEqualizer, arrowEdge: .top) {
                EqualizerView()
                    .frame(width: 400)
            }

            // AirPlay picker
            AirPlayPickerView()
                .frame(width: 32, height: 32)
                .help(L("Change Audio Output"))
                .disabled(self.playbackStore.currentTrack == nil)
            
            // Visualizer button with style menu
            Menu {
                ForEach(PlaybackStore.VisualizerType.allCases) { type in
                    Button {
                        player.activeVisualizer = type
                    } label: {
                        HStack {
                            Text(type.rawValue)
                            if player.activeVisualizer == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(player.activeVisualizer != .none ? .appAccent : .primary.opacity(0.85))
            }
            .menuStyle(.button)
            .buttonStyle(.pressable)
            .help(L("Audio Visualizer"))

            // Mini-Player button
            Button {
                HapticService.toggle()
                MiniPlayerWindowController.shared.show(playbackStore: player)
            } label: {
                Image(systemName: "pip.enter")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .help(L("Detach Mini-Player"))
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            Image(systemName: self.volumeIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 18)

            // Volume slider with immediate updates
            Slider(value: self.$volumeValue, in: 0 ... 1) { editing in
                if editing {
                    // User started dragging
                    self.isAdjustingVolume = true
                } else {
                    // User finished dragging/clicking - apply volume change
                    self.isAdjustingVolume = false
                    // Always apply volume when interaction ends to ensure WebView is synced
                    Task {
                        await self.playbackStore.setVolume(self.volumeValue)
                    }
                }
            }
            .frame(width: 80)
            .controlSize(.small)
            .onChange(of: self.volumeValue) { oldValue, newValue in
                // Apply volume changes in real-time during dragging for immediate feedback
                if self.isAdjustingVolume {
                    // Haptic feedback at slider boundaries
                    if (oldValue > 0 && newValue == 0) || (oldValue < 1 && newValue == 1) {
                        HapticService.sliderBoundary()
                    }
                    Task {
                        await self.playbackStore.setVolume(newValue)
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons (Like/Dislike/Lyrics/Queue)

    private var actionButtons: some View {
        @Bindable var player = self.playbackStore

        return HStack(spacing: 12) {
            // Dislike button
            Button {
                HapticService.toggle()
                self.playbackStore.dislikeCurrentTrack()
            } label: {
                Image(systemName: self.playbackStore.currentTrackLikeStatus == .dislike
                    ? "hand.thumbsdown.fill"
                    : "hand.thumbsdown")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playbackStore.currentTrackLikeStatus == .dislike ? .appAccent : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .symbolEffect(.bounce, value: self.playbackStore.currentTrackLikeStatus == .dislike)
            .accessibilityLabel(L("Dislike"))
            .accessibilityValue(self.playbackStore.currentTrackLikeStatus == .dislike ? L("Disliked") : L("Not disliked"))
            .disabled(self.playbackStore.currentTrack == nil)

            // Like button
            Button {
                HapticService.toggle()
                self.playbackStore.likeCurrentTrack()
            } label: {
                Image(systemName: self.playbackStore.currentTrackLikeStatus == .like
                    ? "hand.thumbsup.fill"
                    : "hand.thumbsup")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playbackStore.currentTrackLikeStatus == .like ? .appAccent : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .symbolEffect(.bounce, value: self.playbackStore.currentTrackLikeStatus == .like)
            .accessibilityLabel(L("Like"))
            .accessibilityValue(self.playbackStore.currentTrackLikeStatus == .like ? L("Liked") : L("Not liked"))
            .disabled(self.playbackStore.currentTrack == nil)

            // Lyrics button
            Button {
                HapticService.toggle()
                withAnimation(AppAnimation.standard) {
                    player.showLyrics.toggle()
                }
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playbackStore.showLyrics ? .appAccent : .primary.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .glassEffectID("lyrics", in: self.playerNamespace)
            .accessibilityIdentifier(AccessibilityID.PlayerBar.lyricsButton)
            .accessibilityLabel(L("Lyrics"))
            .accessibilityValue(self.playbackStore.showLyrics ? L("Showing") : L("Hidden"))

            // Queue button
            Button {
                HapticService.toggle()
                withAnimation(AppAnimation.standard) {
                    player.showQueue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playbackStore.showQueue ? .appAccent : .primary.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .glassEffectID("queue", in: self.playerNamespace)
            .accessibilityIdentifier(AccessibilityID.PlayerBar.queueButton)
            .accessibilityLabel(L("Queue"))
            .accessibilityValue(self.playbackStore.showQueue ? L("Showing") : L("Hidden"))

        }
    }

    private var volumeIcon: String {
        let currentVolume = self.isAdjustingVolume ? self.volumeValue : self.playbackStore.volume
        if currentVolume == 0 {
            return "speaker.slash.fill"
        } else if currentVolume < 0.5 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
}

@available(macOS 15.0, *)
#Preview {
    PlayerBar()
        .environment(PlaybackStore())
        .environment(WebKitManager.shared)
        .frame(width: 600)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
}
