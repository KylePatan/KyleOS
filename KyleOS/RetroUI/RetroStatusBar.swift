import SwiftUI

/// Bottom status strip (spec §33: "READY" / "3 PROJECTS OPEN" style small retro personality
/// details; spec §2's own page-structure diagram ends every screen with an optional status row).
/// Deliberately plain-text, no icons required — callers pass whatever short status line applies.
struct RetroStatusBar: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, RetroTheme.sectionPadding)
        .padding(.vertical, RetroTheme.controlSpacing / 2)
        .background(RetroTheme.panelBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(RetroTheme.border).frame(height: RetroTheme.borderWidth)
        }
    }
}
