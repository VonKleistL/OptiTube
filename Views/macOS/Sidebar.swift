import SwiftUI

/// Sidebar navigation for the main window, styled like Apple Music.
@available(macOS 15.0, *)
struct Sidebar: View {
    @Binding var selection: NavigationItem?

    /// Namespace for glass effect morphing.
    @Namespace private var sidebarNamespace

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Main navigation
                    SidebarItemRow(item: NavigationItem.search, title: L("Search"), systemImage: "magnifyingglass", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.searchItem)
                    SidebarItemRow(item: NavigationItem.home, title: L("Home"), systemImage: "house", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.homeItem)

                    // Discover section
                    Text(L("Discover"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 10)
                        .padding(.bottom, 2)
                    
                    SidebarItemRow(item: NavigationItem.explore, title: L("Explore"), systemImage: "globe", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.exploreItem)
                    SidebarItemRow(item: NavigationItem.charts, title: L("Charts"), systemImage: "chart.line.uptrend.xyaxis", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.chartsItem)
                    SidebarItemRow(item: NavigationItem.moodsAndGenres, title: L("Moods & Genres"), systemImage: "theatermask.and.paintbrush", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.moodsAndGenresItem)
                    SidebarItemRow(item: NavigationItem.newReleases, title: L("New Releases"), systemImage: "sparkles", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.newReleasesItem)
                    SidebarItemRow(item: NavigationItem.podcasts, title: L("Podcasts"), systemImage: "mic.fill", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.podcastsItem)

                    // Collection section
                    Text(L("Collection"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 10)
                        .padding(.bottom, 2)

                    SidebarItemRow(item: NavigationItem.library, title: L("Library"), systemImage: "square.stack.fill", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.libraryItem)
                    SidebarItemRow(item: NavigationItem.likedMusic, title: L("Liked Music"), systemImage: "heart.fill", selection: self.$selection)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.likedMusicItem)
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
            }
            .background(Color.clear)
            .accessibilityIdentifier(AccessibilityID.Sidebar.container)
            .onChange(of: self.selection) { _, newValue in
                if newValue != nil {
                    HapticService.navigation()
                }
            }

            Divider()
                .opacity(0.3)

            SourceToggleView()
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Profile section at bottom
            SidebarProfileView()
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    }
}

@available(macOS 15.0, *)
#Preview {
    Sidebar(selection: .constant(NavigationItem.home))
        .frame(width: 220)
}
