import Foundation
import Observation
import os

/// View model for the TopTracksView.
@MainActor
@Observable
final class TopTracksViewModel {
    /// Current loading state.
    private(set) var loadingState: LoadingState = .idle

    /// All loaded tracks.
    private(set) var tracks: [Track] = []

    private let destination: TopTracksDestination
    let client: any YTMusicClientProtocol
    private let logger = DiagnosticsLogger.api

    init(destination: TopTracksDestination, client: any YTMusicClientProtocol) {
        self.destination = destination
        self.client = client
        // Start with the tracks we already have
        self.tracks = destination.tracks
    }

    /// Loads all tracks if a browse ID is available.
    func load() async {
        // If there's no browse ID, we already have all the tracks
        guard let browseId = destination.tracksBrowseId else {
            self.loadingState = .loaded
            return
        }

        guard self.loadingState != .loading else { return }

        self.loadingState = .loading
        self.logger.info("Loading all artist tracks: \(browseId)")

        do {
            let allTracks = try await client.getArtistTracks(
                browseId: browseId,
                params: self.destination.tracksParams
            )

            if !allTracks.isEmpty {
                self.tracks = allTracks
            }
            self.loadingState = .loaded
            let trackCount = self.tracks.count
            self.logger.info("Loaded \(trackCount) artist tracks")
        } catch is CancellationError {
            self.logger.debug("Artist tracks load cancelled")
            self.loadingState = .loaded // Keep showing what we have
        } catch {
            let errorMessage = error.localizedDescription
            self.logger.error("Failed to load artist tracks: \(errorMessage)")
            // Keep the tracks we already have and just mark as loaded
            self.loadingState = .loaded
        }
    }
}
