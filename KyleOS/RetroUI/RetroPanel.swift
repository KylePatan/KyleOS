import SwiftUI

/// A bordered section panel with an optional title header bar — "cards should feel like panels
/// or windows" (spec §14/§15), not floating rounded cards with soft shadows. Use this instead of
/// a bare `.background(Color.gray.opacity(...))` VStack for any grouped section of content.
struct RetroPanel<Content: View>: View {
    let title: String?
    /// Aesthetic Direction V2 (docs/VISUAL_DESIGN_SYSTEM.md §0, 2026-08-20), Kyle's own words:
    /// "different squares/cards/modules can have slightly different surface treatments... use
    /// colour strategically... slightly glossy or luminous headers in places." `nil` (the default)
    /// still renders a real card — every panel now shares the same rounded/shadowed "2008 web
    /// card" structure — just without a colour tint, for panels that genuinely mix categories
    /// (a Reports summary, a Weekly Board day column with items from several workspaces) or sit in
    /// a module-neutral screen (Settings).
    var accentCategory: RetroTheme.ModuleCategory?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, accentCategory: RetroTheme.ModuleCategory? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accentCategory = accentCategory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                header(title)
                Rectangle()
                    .fill(accentCategory?.accent.opacity(0.35) ?? RetroTheme.border)
                    .frame(height: RetroTheme.borderWidth)
            }
            content
                .padding(RetroTheme.sectionPadding)
        }
        .background(panelBackground, in: RoundedRectangle(cornerRadius: RetroTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RetroTheme.cornerRadius, style: .continuous)
                .strokeBorder(accentCategory?.accent.opacity(0.4) ?? RetroTheme.border, lineWidth: RetroTheme.borderWidth)
        )
        .shadow(color: RetroTheme.shadow, radius: 6, y: 2)
    }

    private func header(_ title: String) -> some View {
        HStack(spacing: 6) {
            if let accentCategory {
                Circle().fill(accentCategory.accent).frame(width: 7, height: 7)
            }
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(accentCategory?.accent ?? RetroTheme.secondaryText)
        }
        .padding(.horizontal, RetroTheme.sectionPadding)
        .padding(.vertical, RetroTheme.controlSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let accentCategory {
                LinearGradient(colors: [accentCategory.softBackground, .clear], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    /// `.background(_:in:)` wants a `ShapeStyle`, not a `View` — `AnyShapeStyle` type-erases the
    /// two branches (`LinearGradient` and `Color` both conform to `ShapeStyle`) so they can share
    /// one return type.
    private var panelBackground: AnyShapeStyle {
        if let accentCategory {
            AnyShapeStyle(LinearGradient(colors: [Color.white, accentCategory.softBackground.opacity(0.5)], startPoint: .top, endPoint: .bottom))
        } else {
            AnyShapeStyle(LinearGradient(colors: [Color.white, RetroTheme.panelBackground], startPoint: .top, endPoint: .bottom))
        }
    }
}
