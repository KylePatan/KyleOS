import SwiftUI

/// Kyle (2026-08-19): "I want to change the top bar and put it on the left hand side again. I
/// like that look better. So HOME, WRITING, SKETCHES, everything gets put away." A direct reversal
/// of Decision Gate C's 2026-08-15 choice (`RetroTopNav`, horizontal — see that file's own doc
/// comment for the reasoning that led there). Reuses `AppNavigationController`'s existing
/// `selection` state unchanged — only the presentation is different, every deep-link/navigate(to:)
/// call site elsewhere in the app is untouched.
///
/// Restyled 2026-08-20 for Aesthetic Direction V2 (docs/VISUAL_DESIGN_SYSTEM.md §0), the pilot
/// area Kyle chose to see the new direction on first: "a soft light blue base, slightly glossy or
/// subtly layered feel, clear navigation zones, active item states that feel tactile... the
/// sidebar should feel like a friendly anchor for the whole app." Every other module's own chrome
/// is untouched by this pass — the sidebar is global chrome, not a per-module component, so it was
/// always in scope regardless of which module gets the new look next.
struct RetroSidebar: View {
    @Environment(AppNavigationController.self) private var navigator
    static let width: CGFloat = 184

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(RetroTheme.sidebarGradientTop.opacity(0.6)).frame(height: RetroTheme.borderWidth)

            VStack(spacing: 3) {
                ForEach(SidebarDestination.allCases) { destination in
                    moduleButton(destination)
                }
            }
            .padding(.horizontal, RetroTheme.controlSpacing)
            .padding(.top, RetroTheme.controlSpacing)

            Spacer(minLength: 0)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [RetroTheme.sidebarGradientTop, RetroTheme.sidebarGradientBottom],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(width: RetroTheme.borderWidth)
        }
    }

    /// "Slightly glossy" per the spec — a soft white highlight fading out from the top edge, the
    /// same restrained trick real glossy-header UI has always used, over the branding block.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("KYLE OS")
                .font(.headline.bold())
                .foregroundStyle(RetroTheme.secondaryText)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(RetroTheme.secondaryText.opacity(0.75))
        }
        .padding(.horizontal, RetroTheme.sectionPadding)
        .padding(.vertical, RetroTheme.controlSpacing + 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
        )
    }

    private func moduleButton(_ destination: SidebarDestination) -> some View {
        let isSelected = (navigator.selection ?? .home) == destination
        let category = Self.accentCategory(for: destination)
        return Button {
            navigator.selection = destination
        } label: {
            Label(destination.title, systemImage: destination.systemImage)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? RetroTheme.primaryText : RetroTheme.secondaryText)
                .padding(.horizontal, RetroTheme.controlSpacing + 4)
                .padding(.vertical, RetroTheme.controlSpacing + 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: RetroTheme.cornerRadius, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.75) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isSelected, let category {
                RoundedRectangle(cornerRadius: 2)
                    .fill(category.accent)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
        .shadow(color: isSelected ? RetroTheme.shadow : .clear, radius: 3, y: 1)
        .animation(RetroTheme.interactionAnimation, value: isSelected)
    }

    /// §0's category language, applied to sidebar icons/active-state accents. Home/Reports/
    /// Settings are utility screens, not creative categories, so they stay neutral — `nil` reads
    /// as "no accent bar," not "forgotten."
    private static func accentCategory(for destination: SidebarDestination) -> RetroTheme.ModuleCategory? {
        switch destination {
        case .writing: return .writing
        case .standUp: return .standUp
        case .clips: return .clips
        case .sketches: return .sketches
        case .calendar: return .calendar
        case .packets: return .completed
        case .submissions: return .submissions
        case .home, .reports, .settings: return nil
        }
    }
}
