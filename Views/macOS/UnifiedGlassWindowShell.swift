import SwiftUI

/// Unified wrapper that applies a continuous ClearGlassBackground to the entire window,
/// replacing all opaque/milky materials in both Music and YouTube modes.
struct UnifiedGlassWindowShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            ClearGlassBackground()
                // A very subtle dark tint to give contrast but remain transparent
                .background(Color.black.opacity(0.05))
                .ignoresSafeArea()
            
            content
        }
    }
}
