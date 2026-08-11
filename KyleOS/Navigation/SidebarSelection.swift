import Foundation

/// Unifies the official PRD destinations with the temporary Dev section so both can live in one
/// sidebar List/selection. Only SidebarDestination is real product navigation.
enum SidebarSelection: Hashable {
    case destination(SidebarDestination)
    case dev(DevDestination)
}
