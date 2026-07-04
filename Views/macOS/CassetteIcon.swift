import SwiftUI

// MARK: - CassetteIcon

/// A custom OTM (music streaming) logo icon view.
@available(macOS 15.0, *)
struct CassetteIcon: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 100
            
            // Letter "O" with integrated play button
            let oCirclePath = Path { path in
                path.addEllipse(in: CGRect(x: 8 * scale, y: 25 * scale,
                                          width: 18 * scale, height: 18 * scale))
            }
            context.stroke(oCirclePath, with: .color(.white), lineWidth: 3.5 * scale)
            
            // Play triangle inside "O"
            let playTrianglePath = Path { path in
                path.move(to: CGPoint(x: 14 * scale, y: 30 * scale))
                path.addLine(to: CGPoint(x: 14 * scale, y: 38 * scale))
                path.addLine(to: CGPoint(x: 20 * scale, y: 34 * scale))
                path.closeSubpath()
            }
            context.fill(playTrianglePath, with: .color(.white))
            
            // Musical note integrated with "O"
            let notePath = Path { path in
                // Note stem
                path.move(to: CGPoint(x: 23 * scale, y: 18 * scale))
                path.addLine(to: CGPoint(x: 23 * scale, y: 40 * scale))
                
                // Note head (bottom circle)
                path.addEllipse(in: CGRect(x: 18 * scale, y: 38 * scale,
                                          width: 7 * scale, height: 5 * scale))
            }
            context.fill(notePath, with: .color(.white))
            
            // Top curve of note
            let noteTopPath = Path { path in
                path.move(to: CGPoint(x: 23 * scale, y: 18 * scale))
                path.addCurve(to: CGPoint(x: 30 * scale, y: 12 * scale),
                            control1: CGPoint(x: 28 * scale, y: 16 * scale),
                            control2: CGPoint(x: 30 * scale, y: 14 * scale))
            }
            context.stroke(noteTopPath, with: .color(.white), lineWidth: 2.5 * scale)
            
            // Letter "T"
            let tPath = Path { path in
                // Top horizontal bar
                path.move(to: CGPoint(x: 40 * scale, y: 25 * scale))
                path.addLine(to: CGPoint(x: 58 * scale, y: 25 * scale))
                // Vertical stem
                path.move(to: CGPoint(x: 49 * scale, y: 25 * scale))
                path.addLine(to: CGPoint(x: 49 * scale, y: 55 * scale))
            }
            context.stroke(tPath, with: .color(.white), lineWidth: 3.5 * scale)
            
            // Letter "M"
            let mPath = Path { path in
                // Left vertical
                path.move(to: CGPoint(x: 62 * scale, y: 55 * scale))
                path.addLine(to: CGPoint(x: 62 * scale, y: 25 * scale))
                // Left diagonal
                path.addLine(to: CGPoint(x: 72 * scale, y: 40 * scale))
                // Right diagonal
                path.addLine(to: CGPoint(x: 82 * scale, y: 25 * scale))
                // Right vertical
                path.addLine(to: CGPoint(x: 82 * scale, y: 55 * scale))
            }
            context.stroke(mPath, with: .color(.white),
                         style: StrokeStyle(lineWidth: 3.5 * scale,
                                          lineCap: .square,
                                          lineJoin: .miter))
            
            // Underline beneath OTM
            let underlinePath = Path { path in
                path.move(to: CGPoint(x: 35 * scale, y: 58 * scale))
                path.addLine(to: CGPoint(x: 87 * scale, y: 58 * scale))
            }
            context.stroke(underlinePath, with: .color(.white), lineWidth: 1.5 * scale)
            
            // Bottom curved swoosh
            let swooshPath = Path { path in
                path.move(to: CGPoint(x: 15 * scale, y: 70 * scale))
                path.addQuadCurve(to: CGPoint(x: 70 * scale, y: 68 * scale),
                                control: CGPoint(x: 42 * scale, y: 75 * scale))
            }
            context.stroke(swooshPath, with: .color(.white),
                         style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

@available(macOS 15.0, *)
#Preview {
    ZStack {
        Color.black
        CassetteIcon(size: 200)
    }
}
