import SwiftUI

/// Slightly-inset bordered field style (spec §10: "form inputs should feel slightly inset into
/// the interface... avoid floating labels, avoid extremely rounded fields"). A `ViewModifier`
/// rather than a `TextFieldStyle` conformance — macOS's `TextFieldStyle` protocol doesn't expose
/// enough of the field's body to draw a custom bevel/border this way.
struct RetroInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: RetroTheme.cornerRadius, style: .continuous)
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, RetroTheme.controlSpacing)
            .padding(.vertical, RetroTheme.controlSpacing / 2)
            .background(RetroTheme.insetBackground, in: shape)
            .overlay(RetroBevel(isPressed: true).clipShape(shape))
            .overlay(shape.strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth))
    }
}

extension View {
    /// Applies the retro inset field appearance. Pair with `.textFieldStyle(.plain)`-compatible
    /// controls (`TextField`, `TextEditor`, `SecureField`).
    func retroInputStyle() -> some View {
        modifier(RetroInputModifier())
    }
}
