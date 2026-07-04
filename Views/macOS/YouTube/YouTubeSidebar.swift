import SwiftUI

// MARK: - YouTubeSidebar

/// Sidebar navigation for the YouTube (video) experience.
///
/// Mirrors the music `Sidebar` structure so toggling sources feels native.
@available(macOS 15.0, *)
struct YouTubeSidebar: View {
    @Binding var selection: YouTubeNavigationItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Main navigation
                    self.row(for: .search)
                    self.row(for: .home)
                    self.row(for: .subscriptions)

                    // Discover section
                    Text(L("Discover"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 10)
                        .padding(.bottom, 2)
                    
                    self.row(for: .explore)

                    // Collection section
                    Text(L("Collection"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 10)
                        .padding(.bottom, 2)
                    
                    self.row(for: .likedVideos)
                    self.row(for: .watchLater)
                    self.row(for: .playlists)
                    self.row(for: .history)
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
            }
            .background(Color.clear)
            .accessibilityIdentifier(AccessibilityID.YouTubeSidebar.container)

            Divider()
                .opacity(0.3)

            SourceToggleView()
                .padding(.horizontal, 12)
                .padding(.top, 8)

            SidebarProfileView()
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    }

    /// Selection binding that adds haptic feedback on change.
    private var listSelection: Binding<YouTubeNavigationItem?> {
        Binding {
            self.selection
        } set: { newValue in
            guard self.selection != newValue else { return }
            self.selection = newValue
            HapticService.navigation()
        }
    }

    private func row(for item: YouTubeNavigationItem) -> some View {
        SidebarItemRow(item: item, title: item.displayName, systemImage: item.icon, selection: self.listSelection)
            .accessibilityIdentifier(AccessibilityID.YouTubeSidebar.item(for: item))
    }
}

// MARK: - AccessibilityID.YouTubeSidebar

extension AccessibilityID {
    enum YouTubeSidebar {
        static let container = "youtubeSidebar"

        static func item(for item: YouTubeNavigationItem) -> String {
            "youtubeSidebar.\(item.rawValue)"
        }
    }
}
