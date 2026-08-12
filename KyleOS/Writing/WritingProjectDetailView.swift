import SwiftUI
import SwiftData

/// PRD §6.4: "A writing project is a container for all related documents." Only Prose documents
/// are creatable from here this increment — Script/Outline/Bible modes aren't built yet
/// (Decision Gate A governs the script editor specifically).
struct WritingProjectDetailView: View {
    let project: ProjectService.Project
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            documentsSection
            Spacer()
        }
        .padding()
        .navigationTitle(project.title)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let projectType = project.projectType {
                    Text(projectType.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Status", selection: Binding(
                    get: { project.displayStatus },
                    set: { ProjectService.setStatus(project, to: $0); try? context.save() }
                )) {
                    ForEach(ProjectService.ProjectStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .frame(width: 160)
            }
            if let deadline = project.deadline {
                Text("Deadline: \(deadline.dueAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Documents").font(.headline)
                Spacer()
                Button {
                    addProseDocument()
                } label: {
                    Label("New Document", systemImage: "plus")
                }
            }
            if project.documents.isEmpty {
                Text("No documents yet. Outline stages are never mandatory — start writing whenever you're ready.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(project.documents.sorted(by: { $0.updatedAt > $1.updatedAt })) { document in
                        NavigationLink(value: DocumentRoute(id: document.persistentModelID)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.title)
                                Text("\(document.documentType.rawValue) · \(document.displayDraftLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addProseDocument() {
        let ordinal = project.documents.filter { $0.documentType == .prose }.count + 1
        let document = DocumentService.createDocument(
            title: ordinal == 1 ? "Untitled" : "Untitled \(ordinal)",
            type: .prose,
            in: project,
            context: context
        )
        try? context.save()
        _ = document
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
    return NavigationStack {
        WritingProjectDetailView(project: project)
    }
    .modelContainer(container)
}
