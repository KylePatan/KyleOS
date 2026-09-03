import Foundation
import SwiftData

/// Reusable domain actions for Folders, kept out of views per CLAUDE.md §4.
///
/// Kyle (2026-09-02): "I should be able to put things in folders so I know what things are what.
/// Like Mac file system, I can highlight multiple in clips and 'Create folder' and put items in
/// it. I also should be able to drag sources and clips and whatever i'm doing, and drag and drop
/// them to organize myself." A Folder is flat (no nesting) and scoped to exactly one content type
/// via `kind` — `SourceListView` only ever shows/creates `.sources` folders, `ClipBoardView` only
/// `.clips` ones. Populating a folder is drag-and-drop (`onDrag`/`onDrop` + `NSItemProvider`, the
/// same proven mechanism `WeeklyBoardView`/`ClipBoardView`'s own lane drops already use — SwiftUI's
/// newer `.draggable`/`.dropDestination` was already confirmed unreliable on macOS in this
/// codebase), not a separate multi-select-then-create flow — "Create Folder" makes an empty,
/// named folder, and items move into it the same way Kyle already organizes everything else in
/// this app.
enum FolderService {
    typealias Folder = KyleOSSchemaV36.Folder
    typealias FolderKind = KyleOSSchemaV36.FolderKind
    typealias Source = KyleOSSchemaV36.Source
    typealias Clip = KyleOSSchemaV36.Clip

    @discardableResult
    static func createFolder(title: String, kind: FolderKind, context: ModelContext) -> Folder {
        let folder = Folder(title: title, kind: kind)
        context.insert(folder)
        return folder
    }

    static func rename(_ folder: Folder, to newTitle: String) {
        folder.title = newTitle
        folder.updatedAt = .now
    }

    static func moveSource(_ source: Source, to folder: Folder?) {
        source.folder = folder
        folder?.updatedAt = .now
    }

    static func moveClip(_ clip: Clip, to folder: Folder?) {
        clip.folder = folder
        folder?.updatedAt = .now
    }

    /// The Sources/Clips inside survive, only detached — same "a Folder is purely organizational"
    /// reasoning as the schema's own `nullify` delete rule on `Folder.sources`/`Folder.clips`;
    /// nothing extra to clean up here beyond the plain delete.
    static func delete(_ folder: Folder, context: ModelContext) {
        context.delete(folder)
    }
}
