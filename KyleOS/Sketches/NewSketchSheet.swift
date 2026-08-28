import SwiftUI

/// Kyle (2026-08-20, following straight on from the Reel feature): "I like the whole system but
/// would rather it be like 'add sketch' in sketches." Previously the only way to start a Sketch
/// project was via Writing's "New Writing Project" sheet, choosing the Sketch type — a real detour
/// for something that conceptually belongs in Sketches. This is a Sketches-native creation flow,
/// mirroring `NewWritingProjectSheet`'s own shape (title + one more field + Create).
///
/// Reel defaults ON — "a really quick reel/sketch that doesn't have a script" is exactly the case
/// this quick-add flow is for; a scripted sketch that still needs writing already has a fine path
/// via Writing, so this is opt-out, not opt-in, for the common case.
struct NewSketchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator

    @State private var title = ""
    @State private var isReel = true

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            Text("Add Sketch").font(.headline).foregroundStyle(RetroTheme.primaryText)

            TextField("Title", text: $title).retroInputStyle()
            Toggle("Reel — no script, ready to edit and post right away", isOn: $isReel)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.retro)
                Button("Create", action: create)
                    .buttonStyle(.retroProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(RetroTheme.sectionPadding + 8)
        .frame(minWidth: 380)
        .background(RetroTheme.panelBackground)
    }

    private func create() {
        // Kyle (2026-08-20): "when a new piece of sketch writing is created - shouldn't it go on
        // the home board?" `ProjectService.createProject` now creates the right WorkItem
        // automatically (`createsWritingTask`, its own default) — a Reel opts out here since its
        // real work happens on the linked Clip instead, not a "Sketch Writing" task with nothing
        // ever written toward it.
        let project = ProjectService.createProject(
            title: title.trimmingCharacters(in: .whitespaces),
            projectType: .sketch,
            createsWritingTask: !isReel,
            in: context
        )
        if isReel {
            let clip = SketchProductionService.markAsReel(project, context: context)
            _ = try? WorkItemService.clipWorkItem(for: clip, context: context)
        }
        try? context.save()
        dismiss()
        if !isReel {
            // Still needs a script written before it can appear on the Sketches board (see
            // SketchProductionService.isProductionProject) — hand off straight to Writing rather
            // than leaving it to be found later.
            navigator.navigate(to: .writingProject(project.persistentModelID))
        }
    }
}

#Preview {
    NewSketchSheet()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(AppNavigationController())
}
