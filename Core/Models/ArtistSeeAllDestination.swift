import Foundation

// MARK: - ArtistSeeAllDestination

/// Navigation destination for an artist shelf's "See all" affordance.
struct ArtistSeeAllDestination: Hashable, Sendable {
    /// Displayed in the destination view's title bar.
    let artistName: String
    /// The shelf's own title ("Albums", "Latest episodes", …) — used as the
    /// destination view's navigation title.
    let sectionTitle: String
    /// The browse endpoint to fetch and render.
    let endpoint: ShelfMoreEndpoint
}
