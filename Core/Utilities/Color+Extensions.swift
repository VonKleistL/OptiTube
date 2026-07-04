import SwiftUI

extension Color {
    /// A robust accent color that falls back to a premium lilac if the asset is missing.
    static var appAccent: Color {
        PackageResourceLookup.brandAccent
    }
}

extension ShapeStyle where Self == Color {
    static var appAccent: Color { .appAccent }
}
