import SwiftUI

/// Tabs that "appear physically connected to the content underneath" (spec §11) — the active tab
/// shares the panel background and drops its bottom border into the content, rather than
/// floating as bare text above empty space. Generic over any `Hashable` tab identifier, matching
/// how every module's own `enum Tab` is already shaped.
struct RetroTabs<Tab: Hashable>: View {
    let tabs: [(tab: Tab, title: String)]
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { entry in
                Button {
                    selection = entry.tab
                } label: {
                    Text(entry.title)
                        .font(.callout)
                        .foregroundStyle(entry.tab == selection ? RetroTheme.primaryText : RetroTheme.secondaryText)
                        .padding(.horizontal, RetroTheme.sectionPadding)
                        .padding(.vertical, RetroTheme.controlSpacing)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .background(entry.tab == selection ? RetroTheme.panelBackground : RetroTheme.background)
                .overlay(alignment: .top) {
                    if entry.tab == selection {
                        Rectangle().fill(RetroTheme.accent).frame(height: 2)
                    }
                }
                .overlay(Rectangle().strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth))
            }
        }
    }
}
