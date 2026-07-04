import SwiftUI

/// A view that renders dynamic audio visualizations using SwiftUI Canvas.
@available(macOS 15.0, *)
struct CanvasVisualizerView: View {
    @Environment(PlaybackStore.self) private var playback
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let levels = playback.audioLevels
                let palette = playback.currentArtworkPalette
                
                switch playback.activeVisualizer {
                case .particles:
                    drawParticles(context: context, size: size, levels: levels, palette: palette, time: timeline.date.timeIntervalSinceReferenceDate)
                case .none:
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Spatial Style
    
    private func drawSpatial(context: GraphicsContext, size: CGSize, levels: [CGFloat], palette: ColorExtractor.ColorPalette, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringCount = 5
        
        for i in 0..<ringCount {
            let ringIndex = CGFloat(i)
            let level = i < levels.count ? levels[i] : 0.2
            
            // Orbital parameters
            let radius = 60.0 + ringIndex * 40.0 + (level * 20.0)
            let rotation = time * (0.5 + Double(i) * 0.2)
            let pitch = 0.5 + 0.3 * sin(time * 0.4 + Double(i)) // Variating perspective pitch
            
            context.drawLayer { ctx in
                ctx.translateBy(x: center.x, y: center.y)
                
                // Simulate 3D rotation
                ctx.rotate(by: Angle(radians: rotation))
                
                let rect = CGRect(x: -radius, y: -radius * pitch, width: radius * 2, height: (radius * 2) * pitch)
                let path = Path(ellipseIn: rect)
                
                ctx.stroke(path, with: .color(palette.primary.opacity(0.6)), style: StrokeStyle(lineWidth: 1.0 + level * 4))
                
                // Add "Glow" points on the ring
                let pointCount = 4
                for p in 0..<pointCount {
                    let angle = rotation + (Double(p) * .pi / 2)
                    let px = radius * cos(angle)
                    let py = radius * pitch * sin(angle)
                    
                    let glowSize = 4.0 + level * 10.0
                    ctx.fill(Path(ellipseIn: CGRect(x: px - glowSize/2, y: py - glowSize/2, width: glowSize, height: glowSize)), with: .color(palette.lightTint))
                }
            }
        }
    }
    
    // MARK: - Pulse Style
    
    private func drawPulse(context: GraphicsContext, size: CGSize, levels: [CGFloat], palette: ColorExtractor.ColorPalette, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseRadius = min(size.width, size.height) * 0.2
        let volume = levels.reduce(0, +) / CGFloat(max(1, levels.count))
        
        let scale = 1.0 + (volume * 0.5)
        let radius = baseRadius * scale
        
        // Multi-layered glow
        for i in 1...3 {
            let opacity = 0.4 / Double(i)
            let burst = radius * (1.0 + CGFloat(i) * 0.2)
            context.fill(Path(ellipseIn: CGRect(x: center.x - burst, y: center.y - burst, width: burst * 2, height: burst * 2)), with: .color(palette.primary.opacity(opacity)))
        }
        
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(palette.lightTint))
    }
    
    // MARK: - Wave Style
    
    private func drawWave(context: GraphicsContext, size: CGSize, levels: [CGFloat], palette: ColorExtractor.ColorPalette) {
        let barWidth = size.width / CGFloat(max(1, levels.count))
        let spacing: CGFloat = 4
        
        for (index, level) in levels.enumerated() {
            let x = CGFloat(index) * barWidth + spacing / 2
            let height = size.height * 0.6 * level
            let y = (size.height - height) / 2
            
            let rect = CGRect(x: x, y: y, width: barWidth - spacing, height: height)
            let path = Path(roundedRect: rect, cornerRadius: 4)
            
            context.fill(path, with: .linearGradient(
                Gradient(colors: [palette.primary, palette.lightTint]),
                startPoint: CGPoint(x: x, y: y),
                endPoint: CGPoint(x: x, y: y + height)
            ))
        }
    }
    
    // MARK: - Particles Style
    
    private func drawParticles(context: GraphicsContext, size: CGSize, levels: [CGFloat], palette: ColorExtractor.ColorPalette, time: TimeInterval) {
        let volume = levels.reduce(0, +) / CGFloat(max(1, levels.count))
        let particleCount = 40
        
        for i in 0..<particleCount {
            let seed = Double(i) * 123.456
            let x = (sin(time * 0.5 + seed) + 1) / 2 * size.width
            let y = (cos(time * 0.3 + seed * 0.5) + 1) / 2 * size.height
            
            let pSize = 4.0 + (volume * 10.0 * sin(time + Double(i)))
            let opacity = 0.3 + (volume * 0.7)
            
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: CGFloat(pSize), height: CGFloat(pSize))), with: .color(palette.lightTint.opacity(opacity)))
        }
    }
}
