import Foundation
import SwiftData

/// Resolves a FileReference's bookmark against the live filesystem. Separate from
/// FileReferenceService (which only creates/edits the record) so the actual disk/bookmark work
/// is independently testable — this is the piece PRD's "Local File References" note wants
/// "tested early in Foundation."
enum FileReferenceResolver {
    typealias FileReference = KyleOSSchemaV27.FileReference

    enum Resolution: Equatable {
        case available(path: String)
        case missing
        case noBookmarkData
    }

    /// Read-only resolution — does not update the stored reference. Use `checkAvailability` to
    /// also persist the result and refresh a stale bookmark.
    static func resolve(_ reference: FileReference) -> Resolution {
        guard let bookmarkData = reference.bookmarkData else { return .noBookmarkData }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return .missing
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        return .available(path: url.path)
    }

    /// Resolves and persists the result. If the file was found at a moved/renamed location
    /// (bookmark still resolvable but stale), refreshes the stored bookmark and path so future
    /// resolutions stay fast and accurate — the file remaining "useful without causing the app
    /// to copy large media" per the PRD's own phrasing. On failure, only `lastKnownAvailable`/
    /// `lastCheckedAt` change; `displayName`/`notes`/`project` are untouched, satisfying "File
    /// References can survive temporary source-file unavailability."
    @discardableResult
    static func checkAvailability(_ reference: FileReference, at checkedAt: Date = .now) -> Bool {
        guard let bookmarkData = reference.bookmarkData else {
            reference.lastKnownAvailable = false
            reference.lastCheckedAt = checkedAt
            return false
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            reference.lastKnownAvailable = false
            reference.lastCheckedAt = checkedAt
            return false
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        if exists {
            reference.originalPath = url.path
            if isStale, let refreshed = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                reference.bookmarkData = refreshed
            }
        }
        reference.lastKnownAvailable = exists
        reference.lastCheckedAt = checkedAt
        return exists
    }
}
