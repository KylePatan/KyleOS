import SwiftUI

/// The "Page Title / Controls" row in the spec's own page-structure diagram (§2) — sits directly
/// under the primary nav, above the working content. Replaces reliance on each module's own
/// `.navigationTitle()` (which had no title bar to render into once `NavigationSplitView`'s
/// sidebar chrome was removed) with an explicit, retro-styled title strip every module shares.
struct RetroPageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(RetroTheme.primaryText)
            Spacer()
            trailing
        }
        .padding(.horizontal, RetroTheme.sectionPadding)
        .padding(.vertical, RetroTheme.controlSpacing + 4)
        .background(RetroTheme.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border).frame(height: RetroTheme.borderWidth)
        }
    }
}
