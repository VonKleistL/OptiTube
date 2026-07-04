import AppKit
import SwiftUI

// MARK: - ClearGlassBackground

/// Native AppKit-backed clear glass background using NSVisualEffectView.
/// Produces true window-behind blur without the milky/foggy veil that
/// `.ultraThinMaterial` introduces at full opacity.
struct ClearGlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = self.material
        view.blendingMode = self.blendingMode
        view.state = self.state
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = self.material
        view.blendingMode = self.blendingMode
        view.state = self.state
    }
}
