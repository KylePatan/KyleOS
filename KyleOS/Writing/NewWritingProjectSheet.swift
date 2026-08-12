import SwiftUI

/// PRD §6.5: "+ New Writing Project should request a title and project type." The PRD also
/// says structured script types should ask whether to begin with an outline or skip directly to
/// writing — that question is moot this increment since outline mode isn't built yet, so every
/// new project simply starts as an empty container (never mandatory, per the PRD's own words).
struct NewWritingProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var projectType: ProjectService.WritingProjectType = .shortStory

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Writing Project").font(.headline)

            TextField("Title", text: $title)
            Picker("Type", selection: $projectType) {
                ForEach(ProjectService.WritingProjectType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 340)
    }

    private func create() {
        ProjectService.createProject(
            title: title.trimmingCharacters(in: .whitespaces),
            projectType: projectType,
            in: context
        )
        try? context.save()
        dismiss()
    }
}

#Preview {
    NewWritingProjectSheet()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
