import SwiftUI

/// A compact, square player view for the detachable mini-player.
@available(macOS 15.0, *)
struct MiniPlayerView: View {
    @Environment(PlaybackStore.self) private var playbackStore
    
    @State private var isHovering = false
    @State private var isShowingVideo = false
    
    // Local state for smooth dragging
    @State private var seekValue: Double = 0
    @State private var isSeeking = false
    @State private var volumeValue: Double = 1.0
    @State private var isAdjustingVolume = false
    
    var body: some View {
        GeometryReader { geo in
            LiquidGlassPlayerView {
                ZStack {
                    // 1. Content Layer (Artwork or Video)
                    if isShowingVideo {
                        VideoWebViewContainer()
                            .background(Color.black)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onAppear {
                                SingletonPlayerWebView.shared.updateDisplayMode(.video)
                            }
                    } else if let track = playbackStore.currentTrack {
                        CachedAsyncImage(url: track.thumbnailURL?.highQualityThumbnailURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: geo.size.width * 0.2))
                                        .foregroundStyle(.secondary)
                                }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onAppear {
                            SingletonPlayerWebView.shared.updateDisplayMode(.hidden)
                        }
                    }
                    
                    // 2. Controls on hover
                    if isHovering {
                        ZStack {
                            Color.black.opacity(0.4)
                            
                            VStack(spacing: 0) {
                                // Top: Mode Toggles (ONLY if track has video)
                                if playbackStore.currentTrackHasVideo {
                                    HStack(spacing: 0) {
                                        Button {
                                            withAnimation(.spring) { isShowingVideo = false }
                                        } label: {
                                            Text("AUDIO")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(!isShowingVideo ? Color.appAccent : Color.clear)
                                                .foregroundStyle(!isShowingVideo ? .white : .white.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            withAnimation(.spring) { isShowingVideo = true }
                                        } label: {
                                            Text("VIDEO")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(isShowingVideo ? Color.appAccent : Color.clear)
                                                .foregroundStyle(isShowingVideo ? .white : .white.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .background(.black.opacity(0.5))
                                    .clipShape(Capsule())
                                    .padding(.top, 12)
                                }
                                
                                Spacer()
                                
                                // Center: Playback controls
                                HStack(spacing: 24) {
                                    Button {
                                        Task { await playbackStore.previous() }
                                    } label: {
                                        Image(systemName: "backward.fill")
                                            .font(.system(size: 20))
                                    }
                                    .buttonStyle(.pressable)
                                    
                                    Button {
                                        Task { await playbackStore.playPause() }
                                    } label: {
                                        Image(systemName: playbackStore.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 28))
                                    }
                                    .buttonStyle(.pressable)
                                    
                                    Button {
                                        Task { await playbackStore.next() }
                                    } label: {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 20))
                                    }
                                    .buttonStyle(.pressable)
                                }
                                .foregroundStyle(.white)
                                
                                Spacer()
                                
                                // Bottom: Seek and Volume sliders
                                VStack(spacing: 8) {
                                    // Seek Slider - Now visible in both modes on hover
                                    Slider(value: $seekValue, in: 0...1) { editing in
                                        if editing {
                                            isSeeking = true
                                        } else {
                                            let seekTime = seekValue * playbackStore.duration
                                            Task {
                                                await playbackStore.seek(to: seekTime)
                                                isSeeking = false
                                            }
                                        }
                                    }
                                    .controlSize(.small) // Mirroring main app
                                    .padding(.horizontal, 16)
                                    
                                    // Volume Slider
                                    HStack(spacing: 8) {
                                        Image(systemName: playbackStore.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.8))
                                        
                                        Slider(value: $volumeValue, in: 0...1) { editing in
                                            isAdjustingVolume = editing
                                            if !editing {
                                                Task { await playbackStore.setVolume(volumeValue) }
                                            }
                                        }
                                        .controlSize(.mini)
                                        .onChange(of: volumeValue) { _, newValue in
                                            if isAdjustingVolume {
                                                Task { await playbackStore.setVolume(newValue) }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
                .onAppear {
                    volumeValue = playbackStore.volume
                }
                .onDisappear {
                    if isShowingVideo {
                        SingletonPlayerWebView.shared.updateDisplayMode(.hidden)
                    }
                }
                .onChange(of: playbackStore.progress) { _, newValue in
                    if !isSeeking, playbackStore.duration > 0 {
                        seekValue = newValue / playbackStore.duration
                    }
                }
                .onChange(of: playbackStore.volume) { _, newValue in
                    if !isAdjustingVolume {
                        volumeValue = newValue
                    }
                }
            }
        }
    }
}
