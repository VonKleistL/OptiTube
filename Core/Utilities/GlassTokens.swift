import SwiftUI

// MARK: - GlassTokens

/// Centralised glass design tokens used across all glass-style surfaces.
/// Use these instead of inline opacity values to keep the look consistent.
enum GlassTokens {
    /// Very subtle dark tint for readability without a heavy material.
    static let panelTint = Color.white.opacity(0.045)

    /// Lighter control background tint (e.g. search bar, chip backgrounds).
    static let controlTint = Color.white.opacity(0.065)

    /// Selected/active state tint.
    static let selectedTint = Color.appAccent.opacity(0.85)

    /// Hover highlight tint for interactive rows.
    static let hoverTint = Color.white.opacity(0.09)

    /// Thin border stroke for glass panels and cards.
    static let stroke = Color.white.opacity(0.10)

    /// Even more subtle stroke for nested elements.
    static let subtleStroke = Color.white.opacity(0.045)

    /// Shadow for floating glass surfaces.
    static let shadow = Color.black.opacity(0.12)

    /// Standard glass corner radius.
    static let cornerRadius: CGFloat = 18

    /// Compact corner radius for chips and smaller elements.
    static let chipRadius: CGFloat = 10
}
