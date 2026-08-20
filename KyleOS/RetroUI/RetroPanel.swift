import SwiftUI

/// A bordered section panel with an optional title header bar — "cards should feel like panels
/// or windows" (spec §14/§15), not floating rounded cards with soft shadows. Use this instead of
/// a bare `.background(Color.gray.opacity(...))` VStack for any grouped section of content.
struct RetroPanel<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(RetroTheme.secondaryText)
                    .padding(.horizontal, RetroTheme.sectionPadding)
                    .padding(.vertical, RetroTheme.controlSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle()
                    .fill(RetroTheme.border)
                    .frame(height: RetroTheme.borderWidth)
            }
            content
                .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.panelBackground, in: RoundedRectangle(cornerRadius: RetroTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RetroTheme.cornerRadius, style: .continuous)
                .strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth)
        )
        .shadow(color: RetroTheme.shadow, radius: 5, y: 2)
    }
}
