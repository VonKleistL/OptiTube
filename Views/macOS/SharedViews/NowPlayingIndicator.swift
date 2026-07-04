import SwiftUI

/// An animated indicator showing sound bars that animate when playing.
/// Used to indicate the currently playing track in lists.
struct NowPlayingIndicator: View {
    let isPlaying: Bool
    let size: CGFloat
    
    @State private var animationOffset: CGFloat = 0
    
    init(isPlaying: Bool, size: CGFloat = 16) {
        self.isPlaying = isPlaying
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: size * 0.1) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.08)
                    .fill(.red)
                    .frame(width: size * 0.15, height: barHeight(for: index))
                    .animation(
                        isPlaying ?
                            .easeInOut(duration: 0.4 + Double(index) * 0.1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1) :
                            .easeInOut(duration: 0.3),
                        value: isPlaying
                    )
            }
        }
        .frame(width: size, height: size)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if isPlaying {
            // Varied heights when playing
            return size * [0.6, 1.0, 0.75][index]
        } else {
            // Equal low height when paused
            return size * 0.3
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NowPlayingIndicator(isPlaying: true)
        NowPlayingIndicator(isPlaying: false)
        NowPlayingIndicator(isPlaying: true, size: 24)
    }
    .padding()
}
