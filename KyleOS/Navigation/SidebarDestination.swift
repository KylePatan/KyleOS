import Foundation

/// The primary navigation destinations. Order originally matched the Master PRD §3's specified
/// sidebar order; `packets` (added 2026-08-19, Kyle's own new "PACKET" section — not a PRD
/// concept) is placed right after Sketches since it curates Writing/Sketch content, ahead of the
/// scheduling-oriented Calendar/Reports/Settings tail.
enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case home
    case writing
    case standUp
    case clips
    case sketches
    case packets
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
        case .packets: return "Packets"
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
        case .packets: return "shippingbox"
        case .calendar: return "calendar"
        case .reports: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}
