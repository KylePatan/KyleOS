import SwiftUI

/// Compact, square-cornered, beveled button — "controls, not marketing calls-to-action" (spec
/// §9). Raised by default; insets slightly (bevel flips, content nudges down 1pt) when pressed
/// (§8's "physical response... communicate what can be clicked"). A real fill (not just a border)
/// plus a soft lift shadow so it reads as a physical control sitting on the panel, not bordered
/// text (Kyle, 2026-08-16: "more button-y... a little smoother and more natural").
struct RetroButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(prominent ? RetroTheme.accentText : RetroTheme.primaryText)
            .padding(.horizontal, RetroTheme.sectionPadding)
            .padding(.vertical, RetroTheme.controlSpacing)
            .background(prominent ? RetroTheme.accent : RetroTheme.buttonBackground)
            .overlay(RetroBevel(isPressed: configuration.isPressed))
            .overlay(Rectangle().strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth))
            .shadow(color: RetroTheme.shadow, radius: configuration.isPressed ? 0 : 2, y: configuration.isPressed ? 0 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(RetroTheme.interactionAnimation, value: configuration.isPressed)
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
