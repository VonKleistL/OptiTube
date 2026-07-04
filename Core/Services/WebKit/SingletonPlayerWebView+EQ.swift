import WebKit

/// Extension to manage the 10-band parametric equalizer via Web Audio API.
/// - Warning: Deprecated. Use native EqualizerService instead.
@available(*, deprecated, message: "Use native EqualizerService instead.")
extension SingletonPlayerWebView {
    
    func setupEQ() {
        // Deprecated: no-op
    }
    
    func syncEQSettings() {
        // Deprecated: no-op
    }
    
    func updateEQBand(frequency: Int, gain: Double) {
        // Deprecated: no-op
    }
    
    func enableEQ(_ enabled: Bool) {
        // Deprecated: no-op
    }

    func enableHaptics(_ enabled: Bool) {
        // Deprecated: no-op
    }
}
