import SwiftUI
import AppKit

/// Unified clear glass background shell for the whole application.
/// Ensures that both sidebar and content share the exact same native blur surface
/// without any milky overlays.
@available(macOS 15.0, *)
struct UnifiedGlassWindowShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Root unified glass layer behind the entire window
            ClearGlassBackground(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
            .ignoresSafeArea()

            // Subtle dark wash for readability, replacing the heavy opacity.
            Color.black.opacity(0.035)
                .ignoresSafeArea()

            // Main UI
            content
                .background(Color.clear)
        }
    }
}
