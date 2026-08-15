import SwiftUI
import AppKit

/// Design tokens for Decision Gate C's visual direction (`docs/VISUAL_DESIGN_SYSTEM.md`,
/// resolved 2026-08-15): "Windows 95/98 structure + late-90s/early-2000s web personality +
/// modern application smoothness." This file is the single place color/spacing/border/corner
/// values live — every `Retro*` component and every reskinned screen should read from here, not
/// hardcode its own values, so a future palette change updates the whole app (spec §31).
///
/// Colors use `Color(light:dark:)` (an `NSColor` dynamic provider) rather than Asset Catalog
/// color sets — no new asset-catalog bookkeeping, and the values are colocated with the rest of
/// the design tokens for easy tuning. Light mode is the default (§21); dark mode reuses the same
/// structure with swapped tokens, not a redesign (§23).
enum RetroTheme {
    // MARK: - Spacing (§3: "12-20px around primary sections, 6-12px between related controls,
    // 16-24px between major sections")

    static let sectionPadding: CGFloat = 16
    static let controlSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 20

    // MARK: - Shape (§7: "0-4px, not modern 12/16/24px rounded cards")

    static let cornerRadius: CGFloat = 2
    static let borderWidth: CGFloat = 1

    // MARK: - Colors

    /// Base window/app background — behind all panels.
    static var background: Color { Color(light: NSColor(white: 0.90, alpha: 1), dark: NSColor(white: 0.15, alpha: 1)) }

    /// Panel/card surfaces sitting on top of `background`.
    static var panelBackground: Color { Color(light: .white, dark: NSColor(white: 0.20, alpha: 1)) }

    /// Inset surfaces — text fields, wells — one step darker (light) / one step darker still (dark)
    /// than the panel they sit in, for the "slightly inset" feel (§10).
    static var insetBackground: Color { Color(light: NSColor(white: 0.96, alpha: 1), dark: NSColor(white: 0.12, alpha: 1)) }

    /// Visible structural borders (§5: "the interface should have edges").
    static var border: Color { Color(light: NSColor(white: 0.60, alpha: 1), dark: NSColor(white: 0.40, alpha: 1)) }

    /// Lighter edge used for the "raised" top/left bevel highlight (§8).
    static var bevelLight: Color { Color(light: .white, dark: NSColor(white: 0.32, alpha: 1)) }

    /// Darker edge used for the "raised" bottom/right bevel shadow (§8).
    static var bevelDark: Color { Color(light: NSColor(white: 0.55, alpha: 1), dark: NSColor(white: 0.05, alpha: 1)) }

    static var primaryText: Color { Color(light: NSColor(white: 0.08, alpha: 1), dark: NSColor(white: 0.94, alpha: 1)) }
    static var secondaryText: Color { Color(light: NSColor(white: 0.35, alpha: 1), dark: NSColor(white: 0.65, alpha: 1)) }

    /// Primary accent (§21: "rich blue" among the suggested classic-computing accents) — active
    /// windows, selected items, the primary navigation's active-module indicator.
    static var accent: Color { Color(light: NSColor(red: 0.11, green: 0.36, blue: 0.80, alpha: 1), dark: NSColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1)) }

    static var accentText: Color { .white }

    /// Deadlines/warnings (§21: "use strong colour for... warnings... deadlines").
    static var warning: Color { Color(light: NSColor(red: 0.75, green: 0.30, blue: 0.05, alpha: 1), dark: NSColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)) }
}

private extension Color {
    /// A `Color` that resolves to `light` or `dark` based on the active appearance, evaluated at
    /// draw time via `NSColor`'s own dynamic-provider mechanism — the standard AppKit-backed way
    /// to get light/dark-adaptive colors without an Asset Catalog color set.
    init(light: NSColor, dark: NSColor) {
        self = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}
