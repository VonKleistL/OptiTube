import Foundation

// MARK: - Like/Dislike/Library Actions

@MainActor
extension PlaybackStore {
    /// Likes the current track (thumbs up).
    func likeCurrentTrack() {
        guard let track = currentTrack else { return }
        self.logger.info("Liking current track: \(track.videoId)")

        // Toggle: if already liked, remove the like
        let newStatus: LikeStatus = self.currentTrackLikeStatus == .like ? .indifferent : .like
        let previousStatus = self.currentTrackLikeStatus
        self.currentTrackLikeStatus = newStatus

        // Use API call for reliable rating
        Task {
            do {
                try await self.ytMusicClient?.rateTrack(videoId: track.videoId, rating: newStatus)
                self.logger.info("Successfully rated track as \(newStatus.rawValue)")
            } catch {
                self.logger.error("Failed to rate track: \(error.localizedDescription)")
                // Revert on failure
                self.currentTrackLikeStatus = previousStatus
            }
        }
    }

    /// Dislikes the current track (thumbs down).
    func dislikeCurrentTrack() {
        guard let track = currentTrack else { return }
        self.logger.info("Disliking current track: \(track.videoId)")

        // Toggle: if already disliked, remove the dislike
        let newStatus: LikeStatus = self.currentTrackLikeStatus == .dislike ? .indifferent : .dislike
        let previousStatus = self.currentTrackLikeStatus
        self.currentTrackLikeStatus = newStatus

        // Use API call for reliable rating
        Task {
            do {
                try await self.ytMusicClient?.rateTrack(videoId: track.videoId, rating: newStatus)
                self.logger.info("Successfully rated track as \(newStatus.rawValue)")
            } catch {
                self.logger.error("Failed to rate track: \(error.localizedDescription)")
                // Revert on failure
                self.currentTrackLikeStatus = previousStatus
            }
        }
    }

    /// Toggles the library status of the current track.
    func toggleLibraryStatus() {
        guard let track = currentTrack else { return }
        self.logger.info("Toggling library status for current track: \(track.videoId)")

        // Determine which token to use based on current state
        let isCurrentlyInLibrary = self.currentTrackInLibrary
        let tokenToUse = isCurrentlyInLibrary
            ? self.currentTrackFeedbackTokens?.remove
            : self.currentTrackFeedbackTokens?.add

        guard let token = tokenToUse else {
            self.logger.warning("No feedback token available for library toggle")
            return
        }

        // Optimistic update
        let previousState = self.currentTrackInLibrary
        self.currentTrackInLibrary.toggle()

        // Use API call for reliable library management
        Task {
            do {
                try await self.ytMusicClient?.editTrackLibraryStatus(feedbackTokens: [token])
                let action = isCurrentlyInLibrary ? "removed from" : "added to"
                self.logger.info("Successfully \(action) library")

                // After successful toggle, we need to swap the tokens
                // The remove token becomes add, and vice versa
                // Re-fetch metadata to get updated tokens
                await self.fetchTrackMetadata(videoId: track.videoId)
            } catch {
                self.logger.error("Failed to toggle library status: \(error.localizedDescription)")
                // Revert on failure
                self.currentTrackInLibrary = previousState
            }
        }
    }

    /// Updates the like status from WebView observation.
    func updateLikeStatus(_ status: LikeStatus) {
        self.currentTrackLikeStatus = status
    }

    /// Resets like/library status when track changes.
    func resetTrackStatus() {
        self.currentTrackLikeStatus = .indifferent
        self.currentTrackInLibrary = false
        self.currentTrackFeedbackTokens = nil
    }

    /// Fetches full track metadata including feedbackTokens from the API.
    func fetchTrackMetadata(videoId: String) async {
        guard let client = ytMusicClient else {
            self.logger.warning("No YTMusicClient available for fetching track metadata")
            return
        }

        do {
            let trackData = try await client.getTrack(videoId: videoId)

            // Update current track with full metadata if it's still the same track
            if self.currentTrack?.videoId == videoId {
                // Preserve the title/artist from WebView if they're better
                let title = self.currentTrack?.title == "Loading..." ? trackData.title : (self.currentTrack?.title ?? trackData.title)
                let artists = self.currentTrack?.artists.isEmpty == true ? trackData.artists : (self.currentTrack?.artists ?? trackData.artists)

                self.currentTrack = Track(
                    id: videoId,
                    title: title,
                    artists: artists,
                    album: trackData.album ?? self.currentTrack?.album,
                    duration: trackData.duration ?? self.currentTrack?.duration,
                    thumbnailURL: trackData.thumbnailURL ?? self.currentTrack?.thumbnailURL,
                    videoId: videoId,
                    musicVideoType: trackData.musicVideoType,
                    likeStatus: trackData.likeStatus,
                    isInLibrary: trackData.isInLibrary,
                    feedbackTokens: trackData.feedbackTokens
                )

                // Update service state
                if let likeStatus = trackData.likeStatus {
                    self.currentTrackLikeStatus = likeStatus
                }
                self.currentTrackInLibrary = trackData.isInLibrary ?? false
                self.currentTrackFeedbackTokens = trackData.feedbackTokens

                // Update video availability based on API-detected musicVideoType
                // This is more reliable than DOM inspection since it comes directly from the API
                if let videoType = trackData.musicVideoType {
                    self.updateVideoAvailability(hasVideo: videoType.hasVideoContent)
                    self.logger.debug("Video availability from API: \(videoType.rawValue) -> hasVideo=\(videoType.hasVideoContent)")
                }

                self.logger.info("Updated track metadata - inLibrary: \(self.currentTrackInLibrary), hasTokens: \(self.currentTrackFeedbackTokens != nil)")
            }
        } catch {
            self.logger.warning("Failed to fetch track metadata: \(error.localizedDescription)")
        }
    }
}
