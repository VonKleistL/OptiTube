import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: WidgetPlaybackData(title: "Song Title", artist: "Artist Name", artworkURL: nil, isPlaying: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = getCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = getCurrentEntry()
        // Update timeline every hour, but app will trigger reloads when state changes
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getCurrentEntry() -> SimpleEntry {
        let defaults = WidgetPlaybackData.defaults
        if let data = defaults?.data(forKey: WidgetPlaybackData.dataKey),
           let decoded = try? JSONDecoder().decode(WidgetPlaybackData.self, from: data) {
            return SimpleEntry(date: Date(), data: decoded)
        }
        return SimpleEntry(date: Date(), data: WidgetPlaybackData(title: "Not Playing", artist: "", artworkURL: nil, isPlaying: false))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetPlaybackData
}

struct OptiTubeWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

@main
struct OptiTubeWidget: Widget {
    let kind: String = "OptiTubeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, *) {
                OptiTubeWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                OptiTubeWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("OptiTube Now Playing")
        .description("See what's playing on OptiTube.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
