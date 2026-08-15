import SwiftUI

/// Compact, square-cornered, beveled button — "controls, not marketing calls-to-action" (spec
/// §9). Raised by default; insets slightly (bevel flips, content nudges down 1pt) when pressed
/// (§8's "physical response... communicate what can be clicked").
struct RetroButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundStyle(prominent ? RetroTheme.accentText : RetroTheme.primaryText)
            .padding(.horizontal, RetroTheme.controlSpacing + 4)
            .padding(.vertical, RetroTheme.controlSpacing / 2)
            .background(prominent ? RetroTheme.accent : RetroTheme.panelBackground)
            .overlay(RetroBevel(isPressed: configuration.isPressed))
            .overlay(Rectangle().strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth))
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

extension ButtonStyle where Self == RetroButtonStyle {
    /// Standard control — most application actions (spec §9: "most application controls should
    /// remain relatively neutral").
    static var retro: RetroButtonStyle { RetroButtonStyle() }
    /// Primary action — uses the accent color, reserved for the one clear default action in a
    /// given context (Save, Add, etc.).
    static var retroProminent: RetroButtonStyle { RetroButtonStyle(prominent: true) }
}
