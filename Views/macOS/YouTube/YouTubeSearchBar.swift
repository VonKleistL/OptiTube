import SwiftUI

// MARK: - YouTubeSearchBar

/// Single unified glass search bar for the YouTube mode.
/// Accepts a search query, a YouTube URL, or a raw video ID.
/// Tapping submit or pressing Return dispatches the action to the view model.
@available(macOS 15.0, *)
struct YouTubeSearchBar: View {
    @Bindable var viewModel: YouTubeViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search YouTube or paste a link…", text: self.$viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused(self.$isFocused)
                .onSubmit {
                    self.viewModel.submitSearchOrURL()
                }

            if !self.viewModel.query.isEmpty {
                Button {
                    self.viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                self.viewModel.submitSearchOrURL()
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.appAccent, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(self.viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GlassTokens.controlTint, in: Capsule())
        .overlay {
            Capsule().stroke(GlassTokens.stroke, lineWidth: 1)
        }
        .shadow(color: GlassTokens.shadow, radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: self.viewModel.query.isEmpty)
    }
}
