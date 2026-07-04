import Foundation

/// Represents the top-level navigation areas of the YouTube video experience.
enum YouTubeNavigationItem: String, Hashable, CaseIterable, Identifiable {
    case home = "Home"
    case search = "Search"
    case subscriptions = "Subscriptions"
    case explore = "Explore"
    case likedVideos = "Liked Videos"
    case watchLater = "Watch Later"
    case playlists = "Playlists"
    case history = "History"

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .home:
            String(localized: "Home")
        case .search:
            String(localized: "Search")
        case .subscriptions:
            String(localized: "Subscriptions")
        case .explore:
            String(localized: "Explore")
        case .likedVideos:
            String(localized: "Liked Videos")
        case .watchLater:
            String(localized: "Watch Later")
        case .playlists:
            String(localized: "Playlists")
        case .history:
            String(localized: "History")
        }
    }

    var icon: String {
        switch self {
        case .home:
            "house"
        case .search:
            "magnifyingglass"
        case .subscriptions:
            "rectangle.stack.badge.play"
        case .explore:
            "globe"
        case .likedVideos:
            "hand.thumbsup.fill"
        case .watchLater:
            "clock"
        case .playlists:
            "list.and.film"
        case .history:
            "clock.arrow.circlepath"
        }
    }
}
