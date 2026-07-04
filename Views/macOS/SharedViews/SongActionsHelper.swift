import Foundation
import SwiftUI

// MARK: - TrackActionsHelper

/// Helper for common track actions like liking, disliking, and adding to library.
@MainActor
enum TrackActionsHelper {
    /// Likes a track via the API (does not play the track).
    static func likeTrack(_ track: Track, likeStatusManager: TrackLikeStatusManager) {
        Task {
            await likeStatusManager.like(track)
        }
    }

    /// Unlikes a track (removes the like rating) via the API.
    static func unlikeTrack(_ track: Track, likeStatusManager: TrackLikeStatusManager) {
        Task {
            await likeStatusManager.unlike(track)
        }
    }

    /// Dislikes a track via the API (does not play the track).
    static func dislikeTrack(_ track: Track, likeStatusManager: TrackLikeStatusManager) {
        Task {
            await likeStatusManager.dislike(track)
        }
    }

    /// Undislikes a track (removes the dislike rating) via the API.
    static func undislikeTrack(_ track: Track, likeStatusManager: TrackLikeStatusManager) {
        Task {
            await likeStatusManager.undislike(track)
        }
    }

    /// Adds a track to the library by playing it and toggling library status.
    /// Note: This still requires playing because library toggle works on current track.
    static func addToLibrary(_ track: Track, playbackStore: PlaybackStore) {
        Task {
            await playbackStore.play(track: track)
            try? await Task.sleep(for: .milliseconds(100))
            playbackStore.toggleLibraryStatus()
        }
    }

    /// Adds a playlist to the library.
    static func addPlaylistToLibrary(
        _ playlist: Playlist,
        client: any YTMusicClientProtocol,
        libraryViewModel: LibraryViewModel?
    ) async {
        do {
            try await client.subscribeToPlaylist(playlistId: playlist.id)
            libraryViewModel?.addToLibrarySet(playlistId: playlist.id)
            await libraryViewModel?.refresh()
            DiagnosticsLogger.api.info("Added playlist to library: \(playlist.title)")
        } catch {
            DiagnosticsLogger.api.error("Failed to add playlist to library: \(error.localizedDescription)")
        }
    }

    /// Removes a playlist from the library.
    static func removePlaylistFromLibrary(
        _ playlist: Playlist,
        client: any YTMusicClientProtocol,
        libraryViewModel: LibraryViewModel?
    ) async {
        do {
            try await client.unsubscribeFromPlaylist(playlistId: playlist.id)
            libraryViewModel?.removeFromLibrarySet(playlistId: playlist.id)
            await libraryViewModel?.refresh()
            DiagnosticsLogger.api.info("Removed playlist from library: \(playlist.title)")
        } catch {
            DiagnosticsLogger.api.error("Failed to remove playlist from library: \(error.localizedDescription)")
        }
    }

    /// Subscribes to a podcast show (adds to library).
    static func subscribeToPodcast(
        _ show: PodcastShow,
        client: any YTMusicClientProtocol,
        libraryViewModel: LibraryViewModel?
    ) async throws {
        try await client.subscribeToPodcast(showId: show.id)
        libraryViewModel?.addToLibrarySet(podcastId: show.id)
        await libraryViewModel?.refresh()
        DiagnosticsLogger.api.info("Subscribed to podcast: \(show.title)")
    }

    /// Unsubscribes from a podcast show (removes from library).
    static func unsubscribeFromPodcast(
        _ show: PodcastShow,
        client: any YTMusicClientProtocol,
        libraryViewModel: LibraryViewModel?
    ) async throws {
        DiagnosticsLogger.api.debug("Attempting to unsubscribe from podcast: \(show.id), libraryViewModel is \(libraryViewModel == nil ? "nil" : "present")")
        try await client.unsubscribeFromPodcast(showId: show.id)
        libraryViewModel?.removeFromLibrarySet(podcastId: show.id)
        await libraryViewModel?.refresh()
        DiagnosticsLogger.api.info("Unsubscribed from podcast: \(show.title)")
    }

    // MARK: - Queue Actions

    /// Adds a track to play next (immediately after current track).
    static func addToQueueNext(_ track: Track, playbackStore: PlaybackStore) {
        playbackStore.insertNextInQueue([track])
        DiagnosticsLogger.ui.info("Added track to play next: \(track.title)")
    }

    /// Adds a track to the end of the queue.
    static func addToQueueLast(_ track: Track, playbackStore: PlaybackStore) {
        playbackStore.appendToQueue([track])
        DiagnosticsLogger.ui.info("Added track to end of queue: \(track.title)")
    }

    /// Adds multiple tracks to play next.
    /// - Parameters:
    ///   - fallbackArtist: Optional artist name used when a track has no artist metadata.
    ///   - fallbackAlbum: Optional album metadata used when a track has no album metadata.
    static func addTracksToQueueNext(
        _ tracks: [Track],
        playbackStore: PlaybackStore,
        fallbackArtist: String? = nil,
        fallbackAlbum: Album? = nil
    ) {
        let cleanedTracks = Self.cleanedTracks(
            tracks,
            fallbackArtist: fallbackArtist,
            fallbackAlbum: fallbackAlbum
        )
        guard !cleanedTracks.isEmpty else { return }

        playbackStore.insertNextInQueue(cleanedTracks)
        DiagnosticsLogger.ui.info("Added \(cleanedTracks.count) tracks to play next")
    }

    /// Adds multiple tracks to the end of the queue.
    /// - Parameters:
    ///   - fallbackArtist: Optional artist name used when a track has no artist metadata.
    ///   - fallbackAlbum: Optional album metadata used when a track has no album metadata.
    static func addTracksToQueueLast(
        _ tracks: [Track],
        playbackStore: PlaybackStore,
        fallbackArtist: String? = nil,
        fallbackAlbum: Album? = nil
    ) {
        let cleanedTracks = Self.cleanedTracks(
            tracks,
            fallbackArtist: fallbackArtist,
            fallbackAlbum: fallbackAlbum
        )
        guard !cleanedTracks.isEmpty else { return }

        playbackStore.appendToQueue(cleanedTracks)
        DiagnosticsLogger.ui.info("Added \(cleanedTracks.count) tracks to end of queue")
    }

    // MARK: - Album Queue Actions

    /// Adds an album's tracks to play next.
    static func addAlbumToQueueNext(
        _ album: Album,
        client: any YTMusicClientProtocol,
        playbackStore: PlaybackStore
    ) {
        Task {
            do {
                let response = try await client.getPlaylist(id: album.id)
                let cleanedTracks = Self.cleanedAlbumTracks(response.detail.tracks, album: album)
                guard !cleanedTracks.isEmpty else { return }

                playbackStore.insertNextInQueue(cleanedTracks)
                DiagnosticsLogger.ui.info("Added album '\(album.title)' (\(cleanedTracks.count) tracks) to play next")
            } catch {
                DiagnosticsLogger.ui.error("Failed to add album to queue: \(error.localizedDescription)")
            }
        }
    }

    /// Adds an album's tracks to the end of the queue.
    static func addAlbumToQueueLast(
        _ album: Album,
        client: any YTMusicClientProtocol,
        playbackStore: PlaybackStore
    ) {
        Task {
            do {
                let response = try await client.getPlaylist(id: album.id)
                let cleanedTracks = Self.cleanedAlbumTracks(response.detail.tracks, album: album)
                guard !cleanedTracks.isEmpty else { return }

                playbackStore.appendToQueue(cleanedTracks)
                DiagnosticsLogger.ui.info("Added album '\(album.title)' (\(cleanedTracks.count) tracks) to end of queue")
            } catch {
                DiagnosticsLogger.ui.error("Failed to add album to queue: \(error.localizedDescription)")
            }
        }
    }

    /// Plays an album immediately, replacing the current queue.
    static func playAlbum(
        _ album: Album,
        client: any YTMusicClientProtocol,
        playbackStore: PlaybackStore
    ) {
        Task {
            do {
                let response = try await client.getPlaylist(id: album.id)
                let cleanedTracks = Self.cleanedAlbumTracks(response.detail.tracks, album: album)
                guard !cleanedTracks.isEmpty else { return }

                await playbackStore.playQueue(cleanedTracks, startingAt: 0)
                DiagnosticsLogger.ui.info("Playing album '\(album.title)' (\(cleanedTracks.count) tracks)")
            } catch {
                DiagnosticsLogger.ui.error("Failed to play album: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private static func cleanedTracks(
        _ tracks: [Track],
        fallbackArtist: String?,
        fallbackAlbum: Album?
    ) -> [Track] {
        tracks.map { track in
            var cleanedArtists = track.artists.compactMap(Self.cleanedArtist)
            if cleanedArtists.isEmpty, let fallbackArtist {
                cleanedArtists = Self.cleanedFallbackArtists(from: fallbackArtist)
            }

            let finalAlbum = track.album ?? fallbackAlbum
            let finalThumbnail = track.thumbnailURL ?? fallbackAlbum?.thumbnailURL

            return Track(
                id: track.id,
                title: track.title,
                artists: cleanedArtists,
                album: finalAlbum,
                duration: track.duration,
                thumbnailURL: finalThumbnail,
                videoId: track.videoId,
                hasVideo: track.hasVideo,
                musicVideoType: track.musicVideoType,
                likeStatus: track.likeStatus,
                isInLibrary: track.isInLibrary,
                feedbackTokens: track.feedbackTokens
            )
        }
    }

    private static func cleanedAlbumTracks(_ tracks: [Track], album: Album) -> [Track] {
        let cleanedAlbumArtists = (album.artists ?? []).compactMap(Self.cleanedArtist)
        let normalizedAlbum = Album(
            id: album.id,
            title: album.title,
            artists: cleanedAlbumArtists.isEmpty ? nil : cleanedAlbumArtists,
            thumbnailURL: album.thumbnailURL,
            year: album.year,
            trackCount: album.trackCount
        )

        return tracks.map { track in
            let sourceArtists = track.artists.isEmpty ? cleanedAlbumArtists : track.artists
            let effectiveArtists = sourceArtists.compactMap(Self.cleanedArtist)
            let resolvedArtists = effectiveArtists.isEmpty ? cleanedAlbumArtists : effectiveArtists

            return Track(
                id: track.id,
                title: track.title,
                artists: resolvedArtists,
                album: track.album ?? normalizedAlbum,
                duration: track.duration,
                thumbnailURL: track.thumbnailURL ?? album.thumbnailURL,
                videoId: track.videoId,
                hasVideo: track.hasVideo,
                musicVideoType: track.musicVideoType,
                likeStatus: track.likeStatus,
                isInLibrary: track.isInLibrary,
                feedbackTokens: track.feedbackTokens
            )
        }
    }

    private static func cleanedArtist(_ artist: Artist) -> Artist? {
        var cleanName = artist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName != "Album" else { return nil }

        if cleanName.hasPrefix("Album, ") {
            cleanName = String(cleanName.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !cleanName.isEmpty else { return nil }
        return Artist(id: artist.id, name: cleanName, thumbnailURL: artist.thumbnailURL)
    }

    private static func cleanedFallbackArtists(from fallbackArtist: String) -> [Artist] {
        var cleanFallback = fallbackArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanFallback == "Album" {
            cleanFallback = "Unknown Artist"
        } else if cleanFallback.hasPrefix("Album, ") {
            cleanFallback = String(cleanFallback.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleanFallback.contains("Album,") {
            let parts = cleanFallback.split(separator: ",", maxSplits: 1)
            if parts.count > 1 {
                cleanFallback = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !cleanFallback.isEmpty else { return [] }
        return [Artist(id: "unknown", name: cleanFallback)]
    }
}

// MARK: - LikeDislikeContextMenu

/// Reusable context menu items for like/dislike actions.
@available(macOS 15.0, *)
struct LikeDislikeContextMenu: View {
    let track: Track
    let likeStatusManager: TrackLikeStatusManager

    var body: some View {
        // Show Unlike if already liked, otherwise show Like
        if self.likeStatusManager.isLiked(self.track) {
            Button {
                TrackActionsHelper.unlikeTrack(self.track, likeStatusManager: self.likeStatusManager)
            } label: {
                Label("Unlike", systemImage: "hand.thumbsup.fill")
            }
        } else {
            Button {
                TrackActionsHelper.likeTrack(self.track, likeStatusManager: self.likeStatusManager)
            } label: {
                Label("Like", systemImage: "hand.thumbsup")
            }

            // Only show Dislike if not already liked
            if self.likeStatusManager.isDisliked(self.track) {
                Button {
                    TrackActionsHelper.undislikeTrack(self.track, likeStatusManager: self.likeStatusManager)
                } label: {
                    Label("Remove Dislike", systemImage: "hand.thumbsdown.fill")
                }
            } else {
                Button {
                    TrackActionsHelper.dislikeTrack(self.track, likeStatusManager: self.likeStatusManager)
                } label: {
                    Label("Dislike", systemImage: "hand.thumbsdown")
                }
            }
        }
    }
}

// MARK: - AddToQueueContextMenu

/// Reusable context menu items for adding tracks to the queue.
@available(macOS 15.0, *)
struct AddToQueueContextMenu: View {
    let track: Track
    let playbackStore: PlaybackStore

    var body: some View {
        Button {
            TrackActionsHelper.addToQueueNext(self.track, playbackStore: self.playbackStore)
        } label: {
            Label(L("Play Next"), systemImage: "text.insert")
        }

        Button {
            TrackActionsHelper.addToQueueLast(self.track, playbackStore: self.playbackStore)
        } label: {
            Label(L("Add to Queue"), systemImage: "text.append")
        }
    }
}

// MARK: - AlbumPlaybackContextMenu

/// Reusable context menu items for album-level playback and queue actions.
@available(macOS 15.0, *)
struct AlbumPlaybackContextMenu: View {
    let album: Album
    let client: any YTMusicClientProtocol
    let playbackStore: PlaybackStore

    var body: some View {
        Button {
            TrackActionsHelper.playAlbum(
                self.album,
                client: self.client,
                playbackStore: self.playbackStore
            )
        } label: {
            Label(L("Play Album"), systemImage: "play.fill")
        }

        Button {
            TrackActionsHelper.addAlbumToQueueNext(
                self.album,
                client: self.client,
                playbackStore: self.playbackStore
            )
        } label: {
            Label(L("Add Album Next"), systemImage: "text.insert")
        }

        Button {
            TrackActionsHelper.addAlbumToQueueLast(
                self.album,
                client: self.client,
                playbackStore: self.playbackStore
            )
        } label: {
            Label(L("Add Album to End"), systemImage: "text.append")
        }
    }
}
