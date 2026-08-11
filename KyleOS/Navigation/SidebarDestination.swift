import Foundation

/// The primary navigation destinations, per Master PRD §3.
/// Order matches the PRD's specified sidebar order; do not reorder without updating the PRD.
enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case home
    case writing
    case standUp
    case clips
    case sketches
    case calendar
    case reports
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .writing: return "Writing"
        case .standUp: return "Stand Up"
        case .clips: return "Clips"
        case .sketches: return "Sketches"
        case .calendar: return "Calendar"
        case .reports: return "Reports"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .writing: return "pencil.and.outline"
        case .standUp: return "mic"
        case .clips: return "film"
        case .sketches: return "theatermasks"
        case .calendar: return "calendar"
        case .reports: return "chart.bar"
        case .settings: return "gearshape"
        }
    }

    /// What phase this destination becomes a real module, shown on its placeholder screen.
    var roadmapNote: String {
        switch self {
        case .home: return "Full dashboard arrives in V0.1 — Home."
        case .writing: return "Screenplay/prose editor arrives in V0.2 — Writing."
        case .standUp: return "Stand Up workflow arrives in V0.3 — Stand Up."
        case .clips: return "Clips pipeline arrives in V0.4 — Clips."
        case .sketches: return "Sketch production workflow arrives in V0.5 — Sketches."
        case .calendar: return "Full Calendar UX and Google Calendar sync arrive in V0.6 — Calendar."
        case .reports: return "Reports arrive in V0.9 — Reports."
        case .settings: return "Work Type Defaults and Creative Capacity settings are being built later in V0 Foundation."
        }
    }
}
