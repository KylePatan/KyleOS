import Foundation

/// Temporary, Foundation-only sidebar entries — NOT part of Master PRD §3's navigation.
/// These exist so we can visually verify domain/persistence work before the module that
/// actually owns this UI gets built. Delete this whole Dev/ group once real modules cover it.
enum DevDestination: String, CaseIterable, Identifiable, Hashable {
    case projects
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .documents: return "Documents"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: return "hammer"
        case .documents: return "doc.text"
        }
    }
}
