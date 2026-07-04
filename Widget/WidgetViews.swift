import SwiftUI
import WidgetKit

/// View for the small-sized widget.
struct SmallWidgetView: View {
    let data: WidgetPlaybackData
    
    var body: some View {
        ZStack {
            if let artworkURL = data.artworkURL {
                NetworkImage(url: artworkURL)
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.3)
            }
            
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading) {
                        Text(data.title)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        Text(data.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: data.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                }
                .padding(8)
                .background(.ultraThinMaterial)
            }
        }
    }
}

/// View for the medium-sized widget.
struct MediumWidgetView: View {
    let data: WidgetPlaybackData
    
    var body: some View {
        HStack(spacing: 16) {
            if let artworkURL = data.artworkURL {
                NetworkImage(url: artworkURL)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                Text(data.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Image(systemName: "backward.fill")
                    Image(systemName: data.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                    Image(systemName: "forward.fill")
                }
                .foregroundStyle(.primary)
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
        .padding()
    }
}

/// Helper for loading network images in widgets.
/// Note: This is simplified for the demonstration. 
/// In a real app, you'd use a more robust caching solution.
struct NetworkImage: View {
    let url: URL
    
    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable()
        } placeholder: {
            Color.gray.opacity(0.2)
        }
    }
}
