import SwiftUI
import SwiftData

/// Kyle (2026-08-20, real use): "can there be an option to right click any item in Kyle OS where
/// you can have the option to 'Archive' which will bring it to the archive section of that module.
/// Or 'delete' that will completely wipe it?" One shared, consistent interaction for both actions
/// wherever they apply, instead of each screen inventing its own row buttons. `onArchive` is
/// optional — some items (an individual Clip, a Packet item) only ever make sense to delete
/// outright, with no "archived" state of their own; passing `nil` just omits that menu entry
/// rather than showing a non-functional one.
///
/// Deliberately additive via `.contextMenu`, not a replacement for any row's existing buttons
/// (open-in-window, explicit trash icons, etc.) — right-click is a new, additional path to the
/// same actions, not a mandate to rip out what already works elsewhere in the app.
extension View {
    /// Kyle (2026-08-20, same real-use pass): "make it so it's not just the text of the project i
    /// can right click but the larger field of that app - so clicking anywhere on home can delete
    /// it if need be." `.contextMenu` alone only reliably registers over whatever a row actually
    /// renders (text, icons) — the padding and `Spacer()` gaps a typical row/card is full of don't
    /// count as "content" for hit-testing by default, the exact same gap this codebase already hit
    /// once for onDrop targets (see WeeklyBoardView's own doc comment on that). `.contentShape
    /// (Rectangle())` right before `.contextMenu` claims the row's *entire* laid-out frame as the
    /// right-click target, not just the glyphs inside it — applied once here so every call site
    /// gets full-row hit-testing automatically, instead of relying on each screen to remember it.
    func archiveDeleteContextMenu(onArchive: (() -> Void)? = nil, onDelete: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .contextMenu {
                if let onArchive {
                    Button {
                        onArchive()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    /// Home shows `WorkItem` rows (Weekly Board, All Tasks), not the real content directly — this
    /// resolves what a WorkItem actually represents (`WorkItemService.underlyingContent`) and
    /// applies the same menu to that. Delete is always offered: when there's real content
    /// (Project/Chunk/Joke/Clip) it deletes that; otherwise (an orphaned WorkItem whose target was
    /// already deleted elsewhere, or a general untargeted session) `WorkItemService.
    /// deleteUnderlyingContent` itself falls back to removing the WorkItem row directly — see that
    /// function's own doc comment for the real bug this closed (a Clip's own "Post" WorkItem
    /// surviving, undeletable, after its Clip was already gone). Archive stays conditional — only
    /// a Project or Joke has an archive state of its own.
    func archiveDeleteContextMenuIfApplicable(for workItem: WorkItemService.WorkItem, context: ModelContext) -> some View {
        let archiveAction = WorkItemService.archiveUnderlyingContent(for: workItem)
        return archiveDeleteContextMenu(
            onArchive: archiveAction.map { action in
                { action(); try? context.save() }
            },
            onDelete: {
                WorkItemService.deleteUnderlyingContent(for: workItem, context: context)
                try? context.save()
            }
        )
    }
}
