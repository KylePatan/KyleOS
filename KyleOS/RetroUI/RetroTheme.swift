import SwiftUI

/// Design tokens for Decision Gate C's visual direction (`docs/VISUAL_DESIGN_SYSTEM.md`,
/// resolved 2026-08-15): "Windows 95/98 structure + late-90s/early-2000s web personality +
/// modern application smoothness." This file is the single place color/spacing/border/corner
/// values live — every `Retro*` component and every reskinned screen should read from here, not
/// hardcode its own values, so a future palette change updates the whole app (spec §31).
///
/// One fixed light palette, no dark-mode variant. Kyle (2026-08-16): "I want it to be a white
/// background and core colour and black and dark blue writing - i don't like this dark mode
/// stuff." This supersedes §23 (the spec's own light/dark mapping) — see
/// `KyleOSApp.swift`'s `NSApp.appearance = .aqua` for the matching native-chrome override.
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

    /// Base window/app background — behind all panels. White, per Kyle's own framing ("white
    /// background... core colour") rather than the spec's original light-gray desktop tone.
    static let background = Color.white

    /// Panel/card surfaces sitting on top of `background` — a hair off pure white so bordered
    /// panels still read as distinct shapes against the page, without introducing visible gray.
    static let panelBackground = Color(red: 0.98, green: 0.98, blue: 0.99)

    /// Inset surfaces — text fields, wells — one step darker than the panel they sit in, for the
    /// "slightly inset" feel (§10).
    static let insetBackground = Color(white: 0.94)

    /// Visible structural borders (§5: "the interface should have edges").
    static let border = Color(white: 0.60)

    /// Lighter edge used for the "raised" top/left bevel highlight (§8).
    static let bevelLight = Color.white

    /// Darker edge used for the "raised" bottom/right bevel shadow (§8).
    static let bevelDark = Color(white: 0.55)

    /// Body text — black, not a dark gray, per Kyle's explicit "black... writing."
    static let primaryText = Color.black

    /// Muted/secondary text — a dark blue-gray rather than plain gray, matching Kyle's "black and
    /// dark blue writing" pairing.
    static let secondaryText = Color(red: 0.20, green: 0.28, blue: 0.42)

    /// Primary accent — a true dark navy (§21 originally called for "rich blue"; darkened here to
    /// match "dark blue writing") — active windows, selected items, the primary navigation's
    /// active-module indicator.
    static let accent = Color(red: 0.06, green: 0.16, blue: 0.48)

    static let accentText = Color.white

    /// Deadlines/warnings (§21: "use strong colour for... warnings... deadlines").
    static let warning = Color(red: 0.75, green: 0.30, blue: 0.05)
}
