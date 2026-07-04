import Foundation
import Observation
import os

/// View model for the ArtistDetailView.
@MainActor
@Observable
final class ArtistDetailViewModel {
    /// Current loading state.
    private(set) var loadingState: LoadingState = .idle

    /// The loaded artist detail.
    private(set) var artistDetail: ArtistDetail?

    /// Whether a subscription operation is in progress.
    private(set) var isSubscribing: Bool = false

    /// Error message from subscription toggle (nil if no error).
    private(set) var subscriptionError: String?

    /// Whether to show all tracks instead of limited preview.
    var showAllTracks: Bool = false

    /// Number of tracks to show in preview mode.
    static let previewTrackCount = 5

    private let artist: Artist
    let client: any YTMusicClientProtocol
    private let logger = DiagnosticsLogger.api

    init(artist: Artist, client: any YTMusicClientProtocol) {
        self.artist = artist
        self.client = client
    }

    /// Loads the artist details including tracks and albums.
    func load() async {
        guard self.loadingState != .loading else { return }

        self.loadingState = .loading
        let artistName = self.artist.name
        self.logger.info("Loading artist: \(artistName)")

        do {
            var detail = try await client.getArtist(id: self.artist.id)

            // Use original artist info as fallback if API returned unknown/empty values
            if detail.name == "Unknown Artist", self.artist.name != "Unknown Artist" {
                let mergedArtist = Artist(
                    id: artist.id,
                    name: self.artist.name,
                    thumbnailURL: detail.thumbnailURL ?? self.artist.thumbnailURL
                )
                detail = ArtistDetail(
                    artist: mergedArtist,
                    description: detail.description,
                    tracks: detail.tracks,
                    albums: detail.albums,
                    thumbnailURL: detail.thumbnailURL ?? self.artist.thumbnailURL,
                    channelId: detail.channelId,
                    isSubscribed: detail.isSubscribed,
                    subscriberCount: detail.subscriberCount,
                    hasMoreTracks: detail.hasMoreTracks,
                    tracksBrowseId: detail.tracksBrowseId,
                    tracksParams: detail.tracksParams
                )
            }

            self.artistDetail = detail
            self.loadingState = .loaded
            let trackCount = detail.tracks.count
            self.logger.info("Artist loaded: \(trackCount) tracks")
        } catch is CancellationError {
            // Task was cancelled (e.g., user navigated away) — reset to idle so it can retry
            self.logger.debug("Artist detail load cancelled")
            self.loadingState = .idle
        } catch {
            self.logger.error("Failed to load artist: \(error.localizedDescription)")
            self.loadingState = .error(LoadingError(from: error))
        }
    }

    /// Refreshes the artist details.
    func refresh() async {
        self.artistDetail = nil
        self.showAllTracks = false
        await self.load()
    }

    /// Toggles subscription status for the artist.
    func toggleSubscription() async {
        guard let detail = artistDetail,
              let channelId = detail.channelId
        else {
            self.logger.warning("Cannot toggle subscription: missing channel ID")
            return
        }

        self.isSubscribing = true
        self.subscriptionError = nil
        defer { isSubscribing = false }

        do {
            if detail.isSubscribed {
                try await self.client.unsubscribeFromArtist(channelId: channelId)
                self.artistDetail?.isSubscribed = false
                self.logger.info("Unsubscribed from artist: \(detail.name)")
            } else {
                try await self.client.subscribeToArtist(channelId: channelId)
                self.artistDetail?.isSubscribed = true
                self.logger.info("Subscribed to artist: \(detail.name)")
            }
        } catch {
            self.subscriptionError = "Failed to update subscription. Please try again."
            self.logger.error("Failed to toggle subscription: \(error.localizedDescription)")
        }
    }

    /// The tracks to display based on showAllTracks state.
    var displayedTracks: [Track] {
        guard let tracks = artistDetail?.tracks else { return [] }
        if self.showAllTracks {
            return tracks
        }
        return Array(tracks.prefix(Self.previewTrackCount))
    }

    /// Whether there are more tracks to show (either loaded or available via API).
    var hasMoreTracks: Bool {
        guard let detail = artistDetail else { return false }
        // Show "See all" if there are more tracks loaded than preview count,
        // OR if the API indicates more tracks are available
        return detail.tracks.count > Self.previewTrackCount || detail.hasMoreTracks
    }

    /// All tracks for the artist (fetched on demand).
    private(set) var allTracks: [Track]?

    /// Fetches all tracks for the artist if not already loaded.
    /// Returns all tracks for queue playback.
    func getAllTracks() async -> [Track] {
        // If we already have all tracks cached, return them
        if let allTracks {
            return allTracks
        }

        // If there's no browse ID, we already have all the tracks from artistDetail
        guard let detail = artistDetail,
              let browseId = detail.tracksBrowseId
        else {
            return self.artistDetail?.tracks ?? []
        }

        self.logger.info("Fetching all artist tracks for queue: \(browseId)")

        do {
            let tracks = try await client.getArtistTracks(
                browseId: browseId,
                params: detail.tracksParams
            )

            if !tracks.isEmpty {
                self.allTracks = tracks
                return tracks
            }
        } catch {
            self.logger.warning("Failed to fetch all tracks: \(error.localizedDescription)")
        }

        // Fallback to existing tracks
        return self.artistDetail?.tracks ?? []
    }
}
