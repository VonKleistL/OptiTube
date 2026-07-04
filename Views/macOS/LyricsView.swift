import FoundationModels
import SwiftUI

/// Right sidebar panel displaying lyrics for the current track.
@available(macOS 15.0, *)
struct LyricsView: View {
    @Environment(PlaybackStore.self) private var playbackStore

    let client: any YTMusicClientProtocol

    @State private var syncedLyricsService = SyncedLyricsService()
    @State private var lastLoadedVideoId: String?
    @State private var isLoadingFallback = false

    // AI explanation state
    @State private var lyricsSummary: LyricsSummary?
    @State private var partialSummary: LyricsSummary.PartiallyGenerated?
    @State private var isExplaining = false
    @State private var showExplanation = false
    @State private var explanationError: String?

    private let logger = DiagnosticsLogger.ai

    /// Namespace for glass effect morphing.
    @Namespace private var lyricsNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                self.headerView

                Divider()
                    .opacity(0.3)

                self.contentView
            }
            .frame(width: 280)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .glassEffectID("lyricsPanel", in: self.lyricsNamespace)
        }
        .glassEffectTransition(.materialize)
        .onChange(of: self.playbackStore.currentTrack?.videoId) { _, newVideoId in
            if let videoId = newVideoId, videoId != self.lastLoadedVideoId {
                self.lyricsSummary = nil
                self.partialSummary = nil
                self.showExplanation = false
                self.explanationError = nil
                Task {
                    await self.loadLyrics(for: videoId)
                }
            }
        }
        .task {
            if let videoId = self.playbackStore.currentTrack?.videoId {
                await self.loadLyrics(for: videoId)
            }
        }
        .onChange(of: self.syncedLyricsService.currentLyrics) { _, newLyrics in
            self.updateLyricsPolling(for: newLyrics)
        }
        .onAppear {
            self.updateLyricsPolling(for: self.syncedLyricsService.currentLyrics)
        }
        .onDisappear {
            SingletonPlayerWebView.shared.stopLyricsPoll()
        }
    }

    private func updateLyricsPolling(for result: LyricResult) {
        if case .synced = result {
            SingletonPlayerWebView.shared.startLyricsPoll()
        } else {
            SingletonPlayerWebView.shared.stopLyricsPoll()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(L("Lyrics"))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()

            if self.syncedLyricsService.currentLyrics.isAvailable {
                Button {
                    if self.showExplanation {
                        self.showExplanation = false
                    } else if self.lyricsSummary != nil {
                        self.showExplanation = true
                    } else {
                        Task {
                            await self.explainLyrics()
                        }
                    }
                } label: {
                    if self.isExplaining {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                            .frame(width: 10, height: 10)
                    } else {
                        Image(systemName: self.showExplanation ? "sparkles.rectangle.stack.fill" : "sparkles")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.showExplanation ? .purple : .secondary)
                .help(L("Explain lyrics with AI"))
                .accessibilityLabel(self.showExplanation ? L("Hide lyrics explanation") : L("Explain lyrics with AI"))
                .requiresIntelligence()
                .disabled(self.isExplaining)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if self.playbackStore.currentTrack == nil {
            self.noTrackPlayingView
        } else if self.syncedLyricsService.isLoading || self.isLoadingFallback {
            self.loadingView
        } else {
            switch self.syncedLyricsService.currentLyrics {
            case let .synced(synced):
                self.syncedLyricsContentView(synced)
            case let .plain(plain):
                self.plainLyricsContentView(plain)
            case .unavailable:
                self.noLyricsView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)
                .frame(width: 20, height: 20)
            Text(L("Loading lyrics..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncedLyricsContentView(_ synced: SyncedLyrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if self.isExplaining || self.showExplanation || self.explanationError != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if self.isExplaining, let partial = self.partialSummary {
                            self.streamingExplanationSection(partial)
                        } else if self.showExplanation, let summary = self.lyricsSummary {
                            self.explanationSection(summary)
                        } else if let error = self.explanationError {
                            self.errorSection(error)
                        }
                    }
                }
                .frame(maxHeight: 200)
                Divider().opacity(0.3)
            }

            SyncedLyricsDisplayView(
                lyrics: synced,
                currentTimeMs: self.playbackStore.currentTimeMs,
                onSeek: { timeMs in
                    Task {
                        await self.playbackStore.seek(to: Double(timeMs) / 1000.0)
                    }
                }
            )
        }
    }

    private func plainLyricsContentView(_ lyrics: Lyrics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if self.isExplaining, let partial = self.partialSummary {
                    self.streamingExplanationSection(partial)
                    Divider().padding(.vertical, 12)
                } else if self.showExplanation, let summary = self.lyricsSummary {
                    self.explanationSection(summary)
                    Divider().padding(.vertical, 12)
                } else if let error = self.explanationError {
                    self.errorSection(error)
                    Divider().padding(.vertical, 12)
                }

                Text(lyrics.text)
                    .font(.system(size: 15, weight: .medium))
                    .lineSpacing(8)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)

                if let source = lyrics.source {
                    Divider().padding(.horizontal, 16)
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func explanationSection(_ summary: LyricsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.pink)
                Text(summary.mood.capitalized)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(summary.themes, id: \.self) { theme in
                        Text(theme)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }

            Text(summary.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(.purple.opacity(0.05))
    }

    /// Shows partial content as it streams in from the AI.
    private func streamingExplanationSection(_ partial: LyricsSummary.PartiallyGenerated) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.pink)
                if let mood = partial.mood {
                    Text(mood.capitalized)
                        .font(.subheadline.weight(.medium))
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if let themes = partial.themes, !themes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.purple.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if let explanation = partial.explanation {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                    Text(L("Analyzing..."))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(.purple.opacity(0.05))
    }

    /// Shows error state for failed AI explanation.
    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L("Retry")) {
                self.explanationError = nil
                Task {
                    await self.explainLyrics()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .background(.orange.opacity(0.05))
    }

    private var noLyricsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(L("No Lyrics Available"))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L("There aren't any lyrics available for this track."))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTrackPlayingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(L("No Track Playing"))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L("Play a track to view its lyrics here."))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadLyrics(for videoId: String) async {
        self.lastLoadedVideoId = videoId
        self.isLoadingFallback = false

        guard let track = self.playbackStore.currentTrack else { return }
        guard track.videoId == videoId else { return }

        let info = LyricsSearchInfo(
            title: track.title,
            artist: track.artistsDisplay,
            album: track.album?.title,
            duration: track.duration,
            videoId: track.videoId
        )

        if SettingsManager.shared.syncedLyricsEnabled {
            await self.syncedLyricsService.fetchLyrics(for: info)
        } else {
            self.syncedLyricsService.currentLyrics = .unavailable
            self.syncedLyricsService.activeProvider = nil
        }

        guard self.lastLoadedVideoId == videoId else { return }
        guard self.playbackStore.currentTrack?.videoId == videoId else { return }

        if case .unavailable = self.syncedLyricsService.currentLyrics {
            self.isLoadingFallback = true
            defer {
                if self.lastLoadedVideoId == videoId {
                    self.isLoadingFallback = false
                }
            }

            do {
                let fetchedLyrics = try await self.client.getLyrics(videoId: videoId)
                if self.lastLoadedVideoId == videoId,
                   self.playbackStore.currentTrack?.videoId == videoId
                {
                    self.syncedLyricsService.fallbackToPlainLyrics(fetchedLyrics, videoId: videoId)
                }
            } catch {
                DiagnosticsLogger.api.error("Failed to load plain lyrics fallback: \(error.localizedDescription)")
                self.syncedLyricsService.currentLyrics = .unavailable
            }
        }
    }

    private func explainLyrics() async {
        guard self.syncedLyricsService.currentLyrics.isAvailable,
              let track = playbackStore.currentTrack
        else { return }

        self.isExplaining = true
        self.explanationError = nil
        self.partialSummary = nil
        self.logger.info("Explaining lyrics for: \(track.title)")

        let instructions = """
        You are a music critic and lyricist. Analyze track lyrics and provide insights about
        their meaning, themes, and emotional content. Be insightful but accessible.
        Don't be overly academic or pretentious.
        """

        guard let session = FoundationModelsService.shared.createAnalysisSession(instructions: instructions) else {
            self.logger.warning("Apple Intelligence not available for lyrics explanation")
            self.explanationError = L("Apple Intelligence is not available")
            self.isExplaining = false
            return
        }

        let textToExplain: String
        switch self.syncedLyricsService.currentLyrics {
        case let .synced(synced):
            textToExplain = synced.lines.map(\.text).joined(separator: "\n")
        case let .plain(plain):
            textToExplain = plain.text
        case .unavailable:
            self.isExplaining = false
            return
        }

        let prompt = """
        Analyze these lyrics for "\(track.title)" by \(track.artistsDisplay):

        \(textToExplain)

        Identify the key themes, overall mood, and explain what the track is about.
        """

        do {
            let stream = session.streamResponse(
                to: prompt,
                generating: LyricsSummary.self
            )

            for try await snapshot in stream {
                self.partialSummary = snapshot.content
            }

            if let final = self.partialSummary,
               let mood = final.mood,
               let themes = final.themes,
               let explanation = final.explanation
            {
                self.lyricsSummary = LyricsSummary(
                    themes: themes,
                    mood: mood,
                    explanation: explanation
                )
                self.showExplanation = true
                self.logger.info("Generated lyrics explanation: mood=\(mood), themes=\(themes.joined(separator: ", "))")
            }
        } catch {
            if let message = AIErrorHandler.handleAndMessage(error, context: "lyrics explanation") {
                self.explanationError = message
            }
        }

        self.partialSummary = nil
        self.isExplaining = false
    }
}


#Preview {
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    LyricsView(client: client)
        .environment(PlaybackStore())
        .frame(height: 600)
}

