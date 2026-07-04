import SwiftUI

// MARK: - YouTubeFilterBar

/// Horizontal chip row showing active search filters.
/// Only shown when the view model is in search mode.
@available(macOS 15.0, *)
struct YouTubeFilterBar: View {
    @Bindable var viewModel: YouTubeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Type filter
                FilterMenu(
                    label: self.viewModel.activeSearchFilters.type.rawValue,
                    isActive: self.viewModel.activeSearchFilters.type != .all
                ) {
                    ForEach(YouTubeSearchTypeFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            self.viewModel.activeSearchFilters.type = filter
                            self.triggerSearch()
                        }
                    }
                }

                // Sort filter
                FilterMenu(
                    label: self.viewModel.activeSearchFilters.sort.rawValue,
                    isActive: self.viewModel.activeSearchFilters.sort != .relevance
                ) {
                    ForEach(YouTubeSearchSortFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            self.viewModel.activeSearchFilters.sort = filter
                            self.triggerSearch()
                        }
                    }
                }

                // Upload date filter
                FilterMenu(
                    label: self.viewModel.activeSearchFilters.uploadDate.rawValue,
                    isActive: self.viewModel.activeSearchFilters.uploadDate != .any
                ) {
                    ForEach(YouTubeSearchUploadDateFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            self.viewModel.activeSearchFilters.uploadDate = filter
                            self.triggerSearch()
                        }
                    }
                }

                // Duration filter
                FilterMenu(
                    label: self.viewModel.activeSearchFilters.duration.rawValue,
                    isActive: self.viewModel.activeSearchFilters.duration != .any
                ) {
                    ForEach(YouTubeSearchDurationFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            self.viewModel.activeSearchFilters.duration = filter
                            self.triggerSearch()
                        }
                    }
                }

                // Clear filters
                if !self.viewModel.activeSearchFilters.isDefault {
                    Button {
                        self.viewModel.activeSearchFilters = YouTubeSearchFilters()
                        self.triggerSearch()
                    } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.red.opacity(0.15), in: Capsule())
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func triggerSearch() {
        Task { await self.viewModel.search() }
    }
}

// MARK: - FilterMenu

@available(macOS 15.0, *)
private struct FilterMenu<Content: View>: View {
    let label: String
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            self.content()
        } label: {
            HStack(spacing: 4) {
                Text(self.label)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                self.isActive ? Color.appAccent.opacity(0.2) : GlassTokens.controlTint,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    self.isActive ? Color.appAccent.opacity(0.6) : GlassTokens.stroke,
                    lineWidth: 1
                )
            }
            .foregroundStyle(self.isActive ? Color.appAccent : .primary)
        }
        .menuStyle(.borderlessButton)
    }
}
