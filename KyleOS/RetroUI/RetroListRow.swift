import SwiftUI

/// One compact, dense line of information — the spec's explicit preference for "rows, lists,
/// tables... over giant cards" (§4's own example: a task row is a single line with checkbox,
/// title, category, due date, and progress, not a tall padded card). A thin bottom border
/// separates rows within a list rather than gaps of whitespace.
struct RetroListRow<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            leading
            Text(title)
                .font(.callout)
                .foregroundStyle(RetroTheme.primaryText)
            Spacer()
            trailing
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
    }
}
