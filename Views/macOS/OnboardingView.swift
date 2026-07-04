import SwiftUI

// MARK: - OnboardingView

/// Onboarding view shown to users before they sign in.
@available(macOS 15.0, *)
struct OnboardingView: View {
    @Environment(AuthService.self) private var authService
    @State private var showLoginSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon and title
            VStack(spacing: 16) {
                CassetteIcon(size: 80)
                    .foregroundStyle(.tint)

                Text(L("Welcome to OptiTube"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L("A native YouTube Music experience for macOS"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 48)

            // Features
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "play.circle.fill",
                    title: L("Background Playback"),
                    description: L("Keep listening even when the window is closed")
                )

                FeatureRow(
                    icon: "rectangle.grid.2x2.fill",
                    title: L("Native Interface"),
                    description: L("Built with SwiftUI for a true macOS experience")
                )

                FeatureRow(
                    icon: "keyboard.fill",
                    title: L("Media Keys"),
                    description: L("Control playback with your keyboard")
                )

                FeatureRow(
                    icon: "person.crop.circle.fill",
                    title: L("Your Library"),
                    description: L("Access your playlists and liked tracks")
                )
            }
            .padding(.horizontal, 60)

            Spacer()

            // Sign in button
            VStack(spacing: 12) {
                Button {
                    self.showLoginSheet = true
                } label: {
                    Text(L("Sign in with Google"))
                        .font(.headline)
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text(L("Sign in to access your YouTube Music library"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(minWidth: 500, minHeight: 500)
        .sheet(isPresented: self.$showLoginSheet) {
            LoginSheet()
        }
    }
}

// MARK: - FeatureRow

/// A row displaying a feature with icon, title, and description.
@available(macOS 15.0, *)
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: self.icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(.headline)

                Text(self.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(macOS 15.0, *)
#Preview {
    OnboardingView()
        .environment(AuthService())
        .environment(WebKitManager.shared)
}
