import Combine
import SwiftUI

/// A view that provides a dynamic background for the player based on the current theme.
@available(macOS 15.0, *)
struct LiquidGlassPlayerView<Content: View>: View {
    @Environment(PlaybackStore.self) private var playback
    let settings = SettingsManager.shared
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            self.themeBackground
                .ignoresSafeArea()

            // Mesh Gradient fallback for Music mode (ambient)
            if settings.ambientBackdropEnabled && settings.appSource == .music && settings.currentTheme != .optiGlass {
                MeshGradientBackground(palette: playback.currentArtworkPalette)
                    .opacity(0.15)
                    .blur(radius: 80)
                    .ignoresSafeArea()
            }

            // Audio Visualizer Overlay
            CanvasVisualizerView()
                .opacity(playback.activeVisualizer != .none ? 0.6 : 0)
                .ignoresSafeArea()

            content
                .background(Color.clear)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: settings.currentTheme)
    }

    @ViewBuilder
    private var themeBackground: some View {
        switch self.settings.currentTheme {
        case .optiTube, .optiGlass:
            UnifiedGlassWindowShell {
                Color.clear
            }
        case .nightshade:
            GalaxyBackground()
        case .darkness:
            DarknessBackground()
        }
    }
}

/// A pure black space-themed background (Black version of Nightshade).
struct DarknessBackground: View {
    var body: some View {
        ZStack {
            // Pure black base
            Color.black

            // Very subtle dark gray gradients for depth
            RadialGradient(
                colors: [Color(white: 0.05), .black],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )

            // Extremely subtle nebula glows (almost invisible but adds depth)
            NebulaGlow(color: .white.opacity(0.03), offset: CGSize(width: -100, height: -100))
            NebulaGlow(color: .blue.opacity(0.02), offset: CGSize(width: 150, height: 100))

            // Stars field (can keep same starfield but maybe dimmer)
            StarField()
                .opacity(0.7)
        }
    }
}

/// Dynamic mesh gradient based on artwork colors.
@available(macOS 15.0, *)
struct MeshGradientBackground: View {
    let palette: ColorExtractor.ColorPalette

    @State private var t: Float = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5 + 0.1 * sin(t), 0.5 + 0.1 * cos(t)], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                palette.secondary, palette.primary, palette.secondary,
                palette.primary, palette.lightTint, palette.primary,
                palette.secondary, palette.primary, palette.secondary
            ]
        )
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.1)) {
                t += 0.05
            }
        }
    }
}

/// A premium dark space-themed background.
struct GalaxyBackground: View {
    var body: some View {
        ZStack {
            // Deep space gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Distant nebula glows
            NebulaGlow(color: .indigo.opacity(0.3), offset: CGSize(width: -200, height: -150))
            NebulaGlow(color: .purple.opacity(0.2), offset: CGSize(width: 200, height: 150))

            // Stars field
            StarField()
        }
    }
}

struct NebulaGlow: View {
    let color: Color
    let offset: CGSize

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 600, height: 600)
            .blur(radius: 120)
            .offset(offset)
    }
}

struct StarField: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for i in 0..<100 {
                    let seed = Double(i) * 123.456
                    let x = (sin(seed) * 0.5 + 0.5) * size.width
                    let y = (cos(seed * 0.7) * 0.5 + 0.5) * size.height

                    let brightness = 0.3 + 0.7 * (sin(t * 0.5 + seed) * 0.5 + 0.5)
                    let pSize = 1.0 + sin(seed * 2)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: pSize, height: pSize)),
                        with: .color(.white.opacity(brightness))
                    )
                }
            }
        }
    }
}
