import SwiftUI

/// Kyle (2026-08-19): "I want to change the top bar and put it on the left hand side again. I
/// like that look better. So HOME, WRITING, SKETCHES, everything gets put away." A direct reversal
/// of Decision Gate C's 2026-08-15 choice (`RetroTopNav`, horizontal — see that file's own doc
/// comment for the reasoning that led there). Reuses `AppNavigationController`'s existing
/// `selection` state unchanged — only the presentation is different, every deep-link/navigate(to:)
/// call site elsewhere in the app is untouched.
struct RetroSidebar: View {
    @Environment(AppNavigationController.self) private var navigator
    static let width: CGFloat = 176

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("KYLE OS")
                    .font(.headline.bold())
                    .foregroundStyle(RetroTheme.primaryText)
                Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
            .padding(.horizontal, RetroTheme.sectionPadding)
            .padding(.vertical, RetroTheme.controlSpacing + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RetroTheme.panelBackground)

            Rectangle().fill(RetroTheme.border).frame(height: RetroTheme.borderWidth)

            VStack(spacing: 0) {
                ForEach(SidebarDestination.allCases) { destination in
                    moduleButton(destination)
                }
            }
            .background(RetroTheme.background)

            Spacer(minLength: 0)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(RetroTheme.background)
        .overlay(alignment: .trailing) {
            Rectangle().fill(RetroTheme.border).frame(width: RetroTheme.borderWidth)
        }
    }

    private func moduleButton(_ destination: SidebarDestination) -> some View {
        let isSelected = (navigator.selection ?? .home) == destination
        return Button {
            navigator.selection = destination
        } label: {
            Label(destination.title, systemImage: destination.systemImage)
                .font(.callout)
                .foregroundStyle(isSelected ? RetroTheme.accentText : RetroTheme.primaryText)
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.vertical, RetroTheme.controlSpacing + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(isSelected ? RetroTheme.accent : Color.clear)
        .animation(RetroTheme.interactionAnimation, value: isSelected)
    }
}
