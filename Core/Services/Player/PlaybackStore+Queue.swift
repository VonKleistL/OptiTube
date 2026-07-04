import Foundation

// MARK: - Queue Management

@MainActor
extension PlaybackStore {
    /// Plays a queue of tracks starting at the specified index.
    func playQueue(_ tracks: [Track], startingAt index: Int = 0) async {
        guard !tracks.isEmpty else { return }
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()
        let safeIndex = max(0, min(index, tracks.count - 1))
        self.queue = tracks
        self.currentIndex = safeIndex
        // Clear mix continuation since this is not a mix queue
        self.mixContinuationToken = nil
        if let track = tracks[safe: safeIndex] {
            await self.play(track: track)
        }
        self.saveQueueForPersistence()
    }

    /// Plays a track and fetches similar tracks (radio queue) in the background.
    /// The queue will be populated with similar tracks from YouTube Music's radio feature.
    func playWithRadio(track: Track) async {
        self.logger.info("Playing with radio: \(track.title)")
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()

        // Clear mix continuation since this is a track radio, not a mix
        self.mixContinuationToken = nil

        // Start with just this track in the queue
        self.queue = [track]
        self.currentIndex = 0
        await self.play(track: track)

        // Fetch radio queue in background
        await self.fetchAndApplyRadioQueue(for: track.videoId)
        self.saveQueueForPersistence()
    }

    /// Plays an artist mix from a mix playlist ID.
    /// Fetches a fresh randomized queue from the API each time.
    /// Supports infinite mix - automatically fetches more tracks as you approach the end.
    /// - Parameters:
    ///   - playlistId: The mix playlist ID (e.g., "RDEM..." for artist mix)
    ///   - startVideoId: Optional video ID to start with. If nil, API picks a random starting point.
    func playWithMix(playlistId: String, startVideoId: String?) async {
        self.logger.info("Playing mix playlist: \(playlistId), startVideoId: \(startVideoId ?? "nil (random)")")
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()

        guard let client = self.ytMusicClient else {
            self.logger.warning("No YTMusicClient available for playing mix")
            return
        }

        do {
            // Fetch mix queue from API
            let result = try await client.getMixQueue(playlistId: playlistId, startVideoId: startVideoId)
            guard !result.tracks.isEmpty else {
                self.logger.warning("Mix queue returned empty")
                return
            }

            // Store continuation token for infinite mix
            self.mixContinuationToken = result.continuationToken

            // Shuffle the queue to get a different order each time
            // YouTube's API returns a personalized but consistent order per session,
            // so we shuffle to give the user variety on each Mix button click
            let shuffledTracks = result.tracks.shuffled()

            // Set up the queue and play the first track
            self.queue = shuffledTracks
            self.currentIndex = 0
            self.currentTrack = shuffledTracks[0]

            // Start playback
            await self.play(videoId: shuffledTracks[0].videoId)

            self.logger.info("Mix queue loaded with \(shuffledTracks.count) tracks, hasContinuation: \(result.continuationToken != nil)")
            self.saveQueueForPersistence()
        } catch {
            self.logger.warning("Failed to fetch mix queue: \(error.localizedDescription)")
        }
    }

    /// Fetches more tracks for the current mix when approaching the end of the queue.
    /// This enables "infinite mix" behavior like YouTube Music web.
    func fetchMoreMixTracksIfNeeded() async {
        let tracksRemaining = self.queue.count - self.currentIndex - 1
        self.logger.debug("Infinite mix check: \(tracksRemaining) tracks remaining, hasContinuation: \(self.mixContinuationToken != nil)")

        // Only fetch if we have a continuation token and we're near the end
        guard let token = mixContinuationToken,
              !isFetchingMoreMixTracks,
              let client = ytMusicClient
        else {
            return
        }

        // Fetch more when we're within 10 tracks of the end
        guard tracksRemaining <= 10 else {
            return
        }

        self.logger.info("Fetching more mix tracks, \(tracksRemaining) remaining in queue")
        self.isFetchingMoreMixTracks = true

        do {
            let result = try await client.getMixQueueContinuation(continuationToken: token)
            self.logger.debug("Continuation returned \(result.tracks.count) tracks, hasNextToken: \(result.continuationToken != nil)")

            // Filter out tracks already in queue to avoid duplicates
            let existingIds = Set(queue.map(\.videoId))
            let newTracks = result.tracks.filter { !existingIds.contains($0.videoId) }

            if !newTracks.isEmpty {
                self.recordQueueStateForUndo()
                // Create a new array to ensure @Observable triggers UI update
                var updatedQueue = self.queue
                updatedQueue.append(contentsOf: newTracks)
                self.queue = updatedQueue
                self.logger.info("Added \(newTracks.count) new tracks to queue, total: \(self.queue.count)")
                self.saveQueueForPersistence()
            }

            // Update continuation token for next batch
            self.mixContinuationToken = result.continuationToken
        } catch {
            self.logger.warning("Failed to fetch more mix tracks: \(error.localizedDescription)")
        }

        self.isFetchingMoreMixTracks = false
    }

    /// Fetches radio queue and applies it, keeping the current track at the front.
    func fetchAndApplyRadioQueue(for videoId: String) async {
        guard let client = ytMusicClient else {
            self.logger.warning("No YTMusicClient available for fetching radio queue")
            return
        }

        do {
            let radioTracks = try await client.getRadioQueue(videoId: videoId)
            guard !radioTracks.isEmpty else {
                self.logger.info("No radio tracks returned")
                return
            }

            // Only update if we're still playing the same track
            guard let currentTrack = self.currentTrack, currentTrack.videoId == videoId else {
                self.logger.info("Track changed, discarding radio queue")
                return
            }

            // Ensure the current track is at the front of the queue
            // The radio queue may or may not include the seed track
            var newQueue: [Track] = []

            // Check if the current track is already in the radio queue
            let radioContainsCurrentTrack = radioTracks.contains { $0.videoId == videoId }

            if radioContainsCurrentTrack {
                // Find the index of current track and reorder queue to start from it
                if let currentTrackIndex = radioTracks.firstIndex(where: { $0.videoId == videoId }) {
                    // Put current track first, then the rest
                    newQueue.append(currentTrack)
                    for (index, track) in radioTracks.enumerated() where index != currentTrackIndex {
                        newQueue.append(track)
                    }
                } else {
                    newQueue = radioTracks
                }
            } else {
                // Current track not in radio queue - prepend it
                newQueue.append(currentTrack)
                newQueue.append(contentsOf: radioTracks)
            }

            if newQueue != self.queue || self.currentIndex != 0 {
                self.clearForwardSkipNavigationStack()
                self.recordQueueStateForUndo()
            }
            self.queue = newQueue
            self.currentIndex = 0
            self.logger.info("Radio queue updated with \(newQueue.count) tracks (current track at front)")
            self.saveQueueForPersistence()
        } catch {
            self.logger.warning("Failed to fetch radio queue: \(error.localizedDescription)")
        }
    }

    /// Clears the entire queue.
    func clearQueueEntirely() {
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()
        self.mixContinuationToken = nil
        self.queue = []
        self.currentIndex = 0
        self.logger.info("Queue cleared entirely")
        self.saveQueueForPersistence()
    }

    /// Clears the playback queue except for the currently playing track.
    func clearQueue() {
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()
        // Clear mix continuation since queue is being manually cleared
        self.mixContinuationToken = nil

        guard let currentTrack else {
            self.queue = []
            self.currentIndex = 0
            self.saveQueueForPersistence()
            return
        }
        // Keep only the current track
        self.queue = [currentTrack]
        self.currentIndex = 0
        self.logger.info("Queue cleared, keeping current track")
        self.saveQueueForPersistence()
    }

    /// Plays a track from the queue at the specified index.
    func playFromQueue(at index: Int) async {
        guard index >= 0, index < self.queue.count else { return }
        self.clearForwardSkipNavigationStack()
        self.currentIndex = index
        if let track = queue[safe: index] {
            await self.play(track: track)
        }
        // Check if we need to fetch more tracks for infinite mix
        await self.fetchMoreMixTracksIfNeeded()
        self.saveQueueForPersistence()
    }

    /// Inserts tracks immediately after the current track.
    /// - Parameter tracks: The tracks to insert into the queue.
    func insertNextInQueue(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()
        let insertIndex = min(self.currentIndex + 1, self.queue.count)
        self.queue.insert(contentsOf: tracks, at: insertIndex)
        self.logger.info("Inserted \(tracks.count) tracks at position \(insertIndex)")
        self.saveQueueForPersistence()
    }

    /// Removes tracks from the queue by video ID.
    /// - Parameter videoIds: Set of video IDs to remove.
    func removeFromQueue(videoIds: Set<String>) {
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()
        let previousCount = self.queue.count
        self.queue.removeAll { videoIds.contains($0.videoId) }

        // Adjust currentIndex if needed
        if let current = currentTrack,
           let newIndex = queue.firstIndex(where: { $0.videoId == current.videoId })
        {
            self.currentIndex = newIndex
        } else if self.currentIndex >= self.queue.count {
            self.currentIndex = max(0, self.queue.count - 1)
        }

        self.logger.info("Removed \(previousCount - self.queue.count) tracks from queue")
        self.saveQueueForPersistence()
    }

    /// Reorders the queue based on a new order of video IDs.
    /// - Parameter videoIds: The new order of video IDs.
    func reorderQueue(videoIds: [String]) {
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()
        var reordered: [Track] = []
        var videoIdToTrack: [String: Track] = [:]

        for track in self.queue {
            videoIdToTrack[track.videoId] = track
        }

        for videoId in videoIds {
            if let track = videoIdToTrack[videoId] {
                reordered.append(track)
            }
        }

        self.queue = reordered

        // Update currentIndex to match current track's new position
        if let current = currentTrack,
           let newIndex = queue.firstIndex(where: { $0.videoId == current.videoId })
        {
            self.currentIndex = newIndex
        }

        self.logger.info("Queue reordered with \(reordered.count) tracks")
        self.saveQueueForPersistence()
    }

    /// Shuffles the queue, keeping the current track in place at the front.
    func shuffleQueue() {
        guard self.queue.count > 1 else { return }
        self.clearForwardSkipNavigationStack()
        self.recordQueueStateForUndo()

        // Remove current track, shuffle the rest, put current track at front
        if let currentTrack = queue[safe: currentIndex] {
            var shuffled = self.queue
            shuffled.remove(at: self.currentIndex)
            shuffled.shuffle()
            shuffled.insert(currentTrack, at: 0)
            self.queue = shuffled
            self.currentIndex = 0
        } else {
            self.queue.shuffle()
            self.currentIndex = 0
        }

        self.logger.info("Queue shuffled")
        self.saveQueueForPersistence()
    }

    /// Adds tracks to the end of the queue.
    /// - Parameter tracks: The tracks to append to the queue.
    func appendToQueue(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        self.recordQueueStateForUndo()
        self.queue.append(contentsOf: tracks)
        self.logger.info("Appended \(tracks.count) tracks to queue")
        self.saveQueueForPersistence()
    }

    /// Proactively fetches and ranks tracks for the Intelligent Queue (Auto-Pilot).
    func fetchAutoPilotTracksIfNeeded() async {
        guard SettingsManager.shared.autoPilotEnabled,
              !isFetchingAutoPilot,
              let currentTrack = currentTrack,
              let client = ytMusicClient
        else {
            return
        }

        // Fetch when we have fewer than 2 suggested tracks left
        guard autoPilotTracks.count < 2 else { return }

        self.logger.info("Fetching new Auto-Pilot suggestions for: \(currentTrack.title)")
        self.isFetchingAutoPilot = true

        do {
            // 1. Get candidate tracks from Radio API
            let candidates = try await client.getRadioQueue(videoId: currentTrack.videoId)
            
            // 2. Rank using local intelligence engine
            let ranked = QueuePredictor.shared.rankCandidates(candidates, limit: 10)
            
            // 3. Filter out tracks already in the manual queue or recently played
            let manualIds = Set(queue.map(\.videoId))
            let historyIds = Set(HistoryManager.shared.events.prefix(10).map(\.videoId))
            
            let filtered = ranked.filter { !manualIds.contains($0.videoId) && !historyIds.contains($0.videoId) }
            
            if !filtered.isEmpty {
                self.autoPilotTracks = filtered
                self.logger.info("Auto-Pilot generated \(filtered.count) new suggestions")
            }
        } catch {
            self.logger.warning("Failed to fetch Auto-Pilot tracks: \(error.localizedDescription)")
        }

        self.isFetchingAutoPilot = false
    }

    // MARK: - Queue Persistence

    private struct PersistedPlaybackSession: Codable {
        let queue: [Track]
        let currentIndex: Int
        let currentVideoId: String?
        let progress: TimeInterval
        let duration: TimeInterval
    }

    private static let savedQueueKey = "optitube.saved.queue"
    private static let savedQueueIndexKey = "optitube.saved.queueIndex"
    private static let savedPlaybackSessionKey = "optitube.saved.playbackSession"

    func saveQueueForPersistence() {
        guard !self.queue.isEmpty else {
            self.removeSavedPlaybackSession()
            self.logger.info("Cleared saved playback session (queue is empty)")
            return
        }

        do {
            let encoder = JSONEncoder()
            let safeIndex = min(max(self.currentIndex, 0), self.queue.count - 1)
            let currentVideoId = self.currentTrack?.videoId ?? self.queue[safe: safeIndex]?.videoId
            let resolvedDuration = max(self.duration, self.currentTrack?.duration ?? self.queue[safe: safeIndex]?.duration ?? 0)
            let clampedProgress = resolvedDuration > 0
                ? min(max(self.progress, 0), resolvedDuration)
                : max(self.progress, 0)

            let queueData = try encoder.encode(self.queue)
            let sessionData = try encoder.encode(
                PersistedPlaybackSession(
                    queue: self.queue,
                    currentIndex: safeIndex,
                    currentVideoId: currentVideoId,
                    progress: clampedProgress,
                    duration: resolvedDuration
                )
            )

            UserDefaults.standard.set(queueData, forKey: Self.savedQueueKey)
            UserDefaults.standard.set(safeIndex, forKey: Self.savedQueueIndexKey)
            UserDefaults.standard.set(sessionData, forKey: Self.savedPlaybackSessionKey)
            self.logger.info("Saved playback session with \(self.queue.count) tracks at index \(safeIndex)")
        } catch {
            self.logger.error("Failed to save playback session: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func restoreQueueFromPersistence() -> Bool {
        let decoder = JSONDecoder()

        if let sessionData = UserDefaults.standard.data(forKey: Self.savedPlaybackSessionKey) {
            do {
                let savedSession = try decoder.decode(PersistedPlaybackSession.self, from: sessionData)
                guard !savedSession.queue.isEmpty else {
                    UserDefaults.standard.removeObject(forKey: Self.savedPlaybackSessionKey)
                    return self.restoreLegacyQueueFromPersistence(using: decoder)
                }

                let resolvedIndex = self.resolvedPersistedQueueIndex(
                    savedIndex: savedSession.currentIndex,
                    currentVideoId: savedSession.currentVideoId,
                    in: savedSession.queue
                )

                self.applyRestoredPlaybackSession(
                    queue: savedSession.queue,
                    currentIndex: resolvedIndex,
                    progress: savedSession.progress,
                    duration: savedSession.duration
                )
                self.logger.info("Restored playback session with \(savedSession.queue.count) tracks at index \(resolvedIndex)")
                return true
            } catch {
                self.logger.error("Failed to restore playback session: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: Self.savedPlaybackSessionKey)
            }
        }

        return self.restoreLegacyQueueFromPersistence(using: decoder)
    }

    func clearSavedQueue() {
        self.removeSavedPlaybackSession()
        self.logger.info("Cleared saved queue")
    }

    private func restoreLegacyQueueFromPersistence(using decoder: JSONDecoder) -> Bool {
        guard let queueData = UserDefaults.standard.data(forKey: Self.savedQueueKey),
              let savedIndex = UserDefaults.standard.object(forKey: Self.savedQueueIndexKey) as? Int
        else {
            self.logger.info("No saved queue found")
            return false
        }

        do {
            let savedQueue = try decoder.decode([Track].self, from: queueData)
            guard !savedQueue.isEmpty else {
                self.clearSavedQueue()
                return false
            }

            let resolvedIndex = self.resolvedPersistedQueueIndex(
                savedIndex: savedIndex,
                currentVideoId: nil,
                in: savedQueue
            )
            let restoredDuration = savedQueue[safe: resolvedIndex]?.duration ?? 0
            self.applyRestoredPlaybackSession(
                queue: savedQueue,
                currentIndex: resolvedIndex,
                progress: 0,
                duration: restoredDuration
            )
            self.logger.info("Restored legacy queue with \(savedQueue.count) tracks at index \(resolvedIndex)")
            return true
        } catch {
            self.logger.error("Failed to restore legacy queue: \(error.localizedDescription)")
            self.clearSavedQueue()
            return false
        }
    }

    private func removeSavedPlaybackSession() {
        UserDefaults.standard.removeObject(forKey: Self.savedQueueKey)
        UserDefaults.standard.removeObject(forKey: Self.savedQueueIndexKey)
        UserDefaults.standard.removeObject(forKey: Self.savedPlaybackSessionKey)
    }

    private func resolvedPersistedQueueIndex(
        savedIndex: Int,
        currentVideoId: String?,
        in queue: [Track]
    ) -> Int {
        if let currentVideoId,
           let matchingIndex = queue.firstIndex(where: { $0.videoId == currentVideoId })
        {
            return matchingIndex
        }

        return min(max(savedIndex, 0), queue.count - 1)
    }

    func applyRestoredPlaybackSession(
        queue: [Track],
        currentIndex: Int,
        progress: TimeInterval,
        duration: TimeInterval
    ) {
        guard let currentTrack = queue[safe: currentIndex] else { return }

        self.clearRestoredPlaybackSessionState()
        self.clearForwardSkipNavigationStack()
        self.queue = queue
        self.currentIndex = currentIndex
        self.currentTrack = currentTrack
        self.showMiniPlayer = false
        self.trackNearingEnd = false
        self.isOptiTubeInitiatedPlayback = false

        let resolvedDuration = max(duration, currentTrack.duration ?? 0)
        let clampedProgress = resolvedDuration > 0 ? min(max(progress, 0), resolvedDuration) : max(progress, 0)

        self.applyInternalPlaybackSnapshot(
            pendingVideoId: currentTrack.videoId,
            hasVideo: currentTrack.musicVideoType?.hasVideoContent ?? currentTrack.hasVideo ?? false,
            progress: clampedProgress,
            duration: resolvedDuration,
            state: .paused
        )
        self.pendingRestoredSeek = clampedProgress
        self.isPendingRestoredLoadDeferred = true

        if let tokens = currentTrack.feedbackTokens {
            self.currentTrackFeedbackTokens = tokens
            self.currentTrackInLibrary = currentTrack.isInLibrary ?? false
            self.currentTrackLikeStatus = currentTrack.likeStatus ?? .indifferent
        } else {
            self.resetTrackStatus()
        }

        Task { [videoId = currentTrack.videoId] in
            await self.fetchTrackMetadata(videoId: videoId)
        }
    }

    // MARK: - Queue Metadata Enrichment

    func startQueueEnrichmentService() {
        self.enrichmentTask?.cancel()
        self.enrichmentTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self.enrichQueueMetadata()
            }
        }
    }

    func stopQueueEnrichmentService() {
        self.enrichmentTask?.cancel()
        self.enrichmentTask = nil
    }

    func identifyTracksNeedingEnrichment() -> [(index: Int, videoId: String)] {
        var tracksNeedingEnrichment: [(index: Int, videoId: String)] = []

        for (index, track) in self.queue.enumerated() {
            let needsEnrichment = track.artists.isEmpty
                || track.artists.allSatisfy { $0.name.isEmpty || $0.name == "Unknown Artist" }
                || track.title.isEmpty
                || track.title == "Loading..."
                || track.thumbnailURL == nil

            if needsEnrichment {
                tracksNeedingEnrichment.append((index: index, videoId: track.videoId))
            }
        }

        return tracksNeedingEnrichment
    }

    func enrichQueueMetadata() async {
        guard let client = self.ytMusicClient else { return }
        let tracksToEnrich = self.identifyTracksNeedingEnrichment()
        guard !tracksToEnrich.isEmpty else { return }

        self.logger.info("Enriching metadata for \(tracksToEnrich.count) tracks in queue")

        for (index, videoId) in tracksToEnrich {
            guard index < self.queue.count, self.queue[index].videoId == videoId else { continue }

            do {
                let enrichedTrack = try await client.getTrack(videoId: videoId)
                if index < self.queue.count, self.queue[index].videoId == videoId {
                    self.queue[index] = enrichedTrack
                    self.logger.debug("Enriched track \(index): '\(enrichedTrack.title)'")
                }

                if tracksToEnrich.count > 1 {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            } catch {
                self.logger.warning("Failed to enrich metadata for track \(videoId): \(error.localizedDescription)")
            }
        }

        self.saveQueueForPersistence()
        self.logger.info("Queue metadata enrichment complete")
    }
}
