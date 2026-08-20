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
    func archiveDeleteContextMenu(onArchive: (() -> Void)? = nil, onDelete: @escaping () -> Void) -> some View {
        contextMenu {
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
    /// applies the same menu to that, or omits it entirely for a general, untargeted session
    /// (nothing exists to archive or delete). Kept here, not duplicated per Home screen, since
    /// both Weekly Board and All Tasks need the exact same resolution.
    @ViewBuilder
    func archiveDeleteContextMenuIfApplicable(for workItem: WorkItemService.WorkItem, context: ModelContext) -> some View {
        if WorkItemService.underlyingContent(for: workItem) != nil {
            let archiveAction = WorkItemService.archiveUnderlyingContent(for: workItem)
            self.archiveDeleteContextMenu(
                onArchive: archiveAction.map { action in
                    { action(); try? context.save() }
                },
                onDelete: {
                    WorkItemService.deleteUnderlyingContent(for: workItem, context: context)
                    try? context.save()
                }
            )
        } else {
            self
        }
    }
}
