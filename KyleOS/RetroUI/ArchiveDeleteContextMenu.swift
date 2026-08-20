import SwiftUI

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
}
