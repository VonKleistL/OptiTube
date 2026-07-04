import Foundation

/// Data structure for sharing playback state between the main app and widgets.
struct WidgetPlaybackData: Codable {
    let title: String
    let artist: String
    let artworkURL: URL?
    let isPlaying: Bool
    
    static let suiteName = "group.com.VonKleistL.OptiTube"
    static let dataKey = "widgetPlaybackData"
    
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
