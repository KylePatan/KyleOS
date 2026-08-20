import SwiftUI

/// A bordered section panel with an optional title header bar — "cards should feel like panels
/// or windows" (spec §14/§15), not floating rounded cards with soft shadows. Use this instead of
/// a bare `.background(Color.gray.opacity(...))` VStack for any grouped section of content.
struct RetroPanel<Content: View>: View {
    let title: String?
    /// Aesthetic Direction V2 (docs/VISUAL_DESIGN_SYSTEM.md §0, 2026-08-20), Kyle's own words:
    /// "different squares/cards/modules can have slightly different surface treatments... use
    /// colour strategically... slightly glossy or luminous headers in places." Opt-in and `nil` by
    /// default — every existing call site across every non-Home module keeps today's exact flat
    /// panel look unchanged; only Home passes a category for now (the pilot Kyle chose), so this
    /// one component can carry both looks at once without a second panel type to keep in sync.
    var accentCategory: RetroTheme.ModuleCategory?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, accentCategory: RetroTheme.ModuleCategory? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accentCategory = accentCategory
        self.content = content()
    }

    private var cornerRadius: CGFloat {
        accentCategory != nil ? RetroTheme.moduleCornerRadius : RetroTheme.cornerRadius
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
        .background(panelBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(accentCategory?.accent.opacity(0.4) ?? RetroTheme.border, lineWidth: RetroTheme.borderWidth)
        )
        .shadow(color: accentCategory != nil ? RetroTheme.moduleShadow : RetroTheme.shadow, radius: accentCategory != nil ? 6 : 5, y: 2)
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
            AnyShapeStyle(RetroTheme.panelBackground)
        }
    }
}
