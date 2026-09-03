import SwiftUI

/// Design tokens for Kyle OS's visual direction (`docs/VISUAL_DESIGN_SYSTEM.md`). Currently
/// **Aesthetic Direction V2** (§0, 2026-08-20): "a colourful late-2000s creative productivity
/// dashboard, redesigned with the smooth interactions, clarity, and polish of a modern desktop
/// operating system" — full system-wide rollout, after piloting on Sidebar + Home first. This
/// supersedes the 2026-08-15 Decision Gate C spec's near-monochrome palette (still described
/// below §0 in the design doc for history, but no longer what's built). This file is the single
/// place color/spacing/border/corner values live — every `Retro*` component and every screen
/// should read from here, not hardcode its own values, so a future palette change updates the
/// whole app from one place (spec §31).
///
/// One fixed light palette, no dark-mode variant. Kyle (2026-08-16): "I want it to be a white
/// background and core colour and black and dark blue writing - i don't like this dark mode
/// stuff." — still true today, just "white" is now the warm cream §0 asks for, not stark white.
enum RetroTheme {
    // MARK: - Spacing (§3: "12-20px around primary sections, 6-12px between related controls,
    // 16-24px between major sections")

    static let sectionPadding: CGFloat = 16
    static let controlSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 20

    /// Kyle (2026-08-27): "When there are many items anywhere, it has to be able to scroll to see
    /// everything." A `List` embedded in a `RetroPanel` needs an explicit frame height to behave
    /// correctly in this codebase's flexible layouts — an `idealHeight` hint alone made it
    /// greedily expand to fill all available space even with just 2 rows (see AllTasksView's own
    /// 2026-08-16 fix note) — so every such List sizes to its content height UP TO this cap, and
    /// relies on `List`'s own built-in scrolling past that, instead of growing without bound and
    /// clipping off-screen with no way to reach the rest. One shared constant so every list in the
    /// app scrolls at a consistent, easy-to-retune point.
    static let maxListHeight: CGFloat = 560

    // MARK: - Motion (Kyle, 2026-08-16: "smoother and more natural." §0 (2026-08-20): "soft
    // transitions, smooth hover states... subtle easing" — same 100-200ms range both specs ask for.)

    static let interactionAnimation = Animation.easeOut(duration: 0.12)

    // MARK: - Shape. §0 (2026-08-20): "rounded rectangles" throughout, "a 2008 website... redesigned
    // with modern UX standards" — a real step up from the original Decision Gate C's sharp 0-4px
    // rule (already loosened once, 2026-08-19, to a "very slight" 6px; §0 goes further). One shared
    // token, so this single change cascades through every Retro* component that reads it.

    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 1

    // MARK: - Colors

    /// Base window/app background — behind all panels. Warm cream, not stark white (§0: "warm
    /// cream or soft white backgrounds") — the late-2000s-web warmth that separates this from a
    /// sterile modern SaaS dashboard.
    static let background = Color(red: 0.99, green: 0.97, blue: 0.92)

    /// Panel/card surfaces sitting on top of `background` — a hair off pure white so bordered
    /// panels still read as distinct shapes against the page, without introducing visible gray.
    static let panelBackground = Color(red: 0.98, green: 0.98, blue: 0.99)

    /// Standard (non-prominent) button fill — a visible step up from `panelBackground` so buttons
    /// read as physical controls sitting on a panel, not just bordered text (Kyle, 2026-08-16:
    /// "more button-y"; §0: "rounded rectangles, subtle gradients or layered fills").
    static let buttonBackground = Color(white: 0.93)

    /// Inset surfaces — text fields, wells — one step darker than the panel they sit in, for the
    /// "slightly inset" feel (§10).
    static let insetBackground = Color(white: 0.94)

    /// Soft lift under panels/buttons — §0: "raised card feeling," a touch stronger than the
    /// original Decision Gate C shadow to match the 2008-web "slightly dimensional" surfaces.
    static let shadow = Color.black.opacity(0.16)

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

    // MARK: - Aesthetic Direction V2 (docs/VISUAL_DESIGN_SYSTEM.md §0, 2026-08-20)
    //
    // "Kyle OS should feel like a colourful late-2000s creative productivity dashboard, redesigned
    // with the smooth interactions, clarity, and polish of a modern desktop operating system."
    // Full system-wide rollout (Kyle, after seeing the Sidebar + Home pilot: "love it - let's push
    // this and make the entire app look like this") — every module now reads these tokens.

    /// The sidebar's own light-blue base, top-to-bottom gradient stops (§0 §2: "light blue, pale
    /// cyan... maybe a gentle gradient, not flat flat flat").
    static let sidebarGradientTop = Color(red: 0.70, green: 0.86, blue: 0.96)
    static let sidebarGradientBottom = Color(red: 0.86, green: 0.94, blue: 0.98)

    /// §0's category colour language: "writing = warm yellow/gold, stand-up = orange/coral, clips
    /// = pink/red, sketches = green, calendar = blue, deadlines = red, completed = mint or light
    /// green... gives the OS an immediate visual language." Mirrors `WorkItemService.Workspace`
    /// 1:1 for the four content workspaces, plus three cross-cutting semantic ones (calendar/
    /// deadline/completed) that apply regardless of workspace.
    enum ModuleCategory: CaseIterable {
        case writing, standUp, clips, sketches, submissions, calendar, deadline, completed

        var accent: Color {
            switch self {
            case .writing: return Color(red: 0.87, green: 0.67, blue: 0.13)     // warm yellow/gold
            case .standUp: return Color(red: 0.93, green: 0.47, blue: 0.24)     // orange/coral
            case .clips: return Color(red: 0.90, green: 0.32, blue: 0.52)       // pink/red
            case .sketches: return Color(red: 0.28, green: 0.68, blue: 0.42)    // green
            case .submissions: return Color(red: 0.55, green: 0.36, blue: 0.87) // purple
            case .calendar: return Color(red: 0.24, green: 0.55, blue: 0.85)    // blue
            case .deadline: return Color(red: 0.82, green: 0.24, blue: 0.24)    // red
            case .completed: return Color(red: 0.33, green: 0.76, blue: 0.56)   // mint
            }
        }

        /// A soft tint of the same accent, for card backgrounds/badges where the full-strength
        /// colour would be too loud — §0's own "controlled... not neon chaos" instruction.
        var softBackground: Color { accent.opacity(0.14) }
    }
}

extension WorkItemService.Workspace {
    /// The 1:1 mapping §0's category language is built on — every Home row showing a WorkItem
    /// (Weekly Board, All Tasks, Post It) reads this to pick its accent, so a workspace's colour
    /// can never drift between screens.
    var moduleCategory: RetroTheme.ModuleCategory {
        switch self {
        case .writing: return .writing
        case .standUp: return .standUp
        case .clips: return .clips
        case .sketches: return .sketches
        case .submissions: return .submissions
        }
    }
}
