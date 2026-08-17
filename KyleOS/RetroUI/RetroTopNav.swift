import SwiftUI

/// Primary application chrome (spec §13): "KYLE OS / HOME | WRITING | STAND UP | ..." — a
/// horizontal top navigation bar replacing the original `NavigationSplitView` sidebar. "Avoid
/// giant sidebar navigation unless it clearly improves a specific screen... horizontal navigation
/// near the top supports the intended top-down architecture." Secondary/contextual navigation
/// (a module's own project list, a Chunk list, etc.) still lives inside that module's own content
/// area — this bar only ever switches between the primary destinations.
struct RetroTopNav: View {
    @Environment(AppNavigationController.self) private var navigator

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("KYLE OS")
                    .font(.headline.bold())
                    .foregroundStyle(RetroTheme.primaryText)
                Spacer()
                Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
            .padding(.horizontal, RetroTheme.sectionPadding)
            .padding(.vertical, RetroTheme.controlSpacing)
            .background(RetroTheme.panelBackground)

            Rectangle().fill(RetroTheme.border).frame(height: RetroTheme.borderWidth)

            HStack(spacing: 0) {
                ForEach(SidebarDestination.allCases) { destination in
                    moduleButton(destination)
                }
                Spacer(minLength: 0)
            }
            .background(RetroTheme.background)

            Rectangle().fill(RetroTheme.border).frame(height: RetroTheme.borderWidth)
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
                .padding(.horizontal, RetroTheme.controlSpacing + 4)
                .padding(.vertical, RetroTheme.controlSpacing)
        }
        .buttonStyle(.plain)
        .background(isSelected ? RetroTheme.accent : Color.clear)
        .animation(RetroTheme.interactionAnimation, value: isSelected)
    }
}
