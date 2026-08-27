import SwiftUI

/// Sketches-native "Add Sketch"-style creation flow (`NewSketchSheet`), same shape here: title +
/// one more field + Create, reachable straight from the Submissions board's own toolbar rather
/// than a detour through Home's Quick Add (which also gets its own "Submission" entry — see
/// `QuickAddButton` — for the "add it without leaving whatever screen I'm on" case).
struct NewSubmissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date.now

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            Text("Add Submission").font(.headline).foregroundStyle(RetroTheme.primaryText)
            TextField("Festival or production company", text: $title).retroInputStyle()
            Toggle("Due date known", isOn: $hasDueDate.animation())
            if hasDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.retro)
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
        SubmissionService.createSubmission(
            title: title.trimmingCharacters(in: .whitespaces),
            dueAt: hasDueDate ? dueDate : nil,
            context: context
        )
        try? context.save()
        dismiss()
    }
}

#Preview {
    NewSubmissionSheet()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
