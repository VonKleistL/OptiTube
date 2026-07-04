import SwiftUI

@available(macOS 15.0, *)
struct SidebarItemRow<T: Equatable>: View {
    let item: T
    let title: String
    let systemImage: String
    @Binding var selection: T?

    @State private var isHovering = false

    var body: some View {
        Button {
            self.selection = self.item
        } label: {
            HStack(spacing: 8) {
                Image(systemName: self.systemImage)
                    .frame(width: 16, alignment: .center)
                Text(self.title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            self.backgroundTint,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .animation(.easeOut(duration: 0.12), value: self.isHovering)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }

    private var backgroundTint: Color {
        if self.selection == self.item {
            GlassTokens.selectedTint
        } else if self.isHovering {
            GlassTokens.hoverTint
        } else {
            Color.clear
        }
    }
}
