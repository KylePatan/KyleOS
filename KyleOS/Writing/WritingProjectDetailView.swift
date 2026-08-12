import SwiftUI
import SwiftData

/// PRD §6.4: "A writing project is a container for all related documents." Only Prose and Act
/// Outline documents are creatable from here — Script/Scene Outline/Bible modes aren't built yet
/// (Decision Gate A governs the script editor specifically). Total time reuses
/// `HomeService.totalLoggedSeconds`, the same cumulative-across-all-WorkItems calculation Home's
/// project cards already use (PRD §4.3: "include all logged work across the project").
struct WritingProjectDetailView: View {
    let project: ProjectService.Project
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let lastOpened = project.lastOpenedDocument {
                continueWritingSection(for: lastOpened)
            }
            Divider()
            documentsSection
            Spacer()
        }
        .padding()
        .navigationTitle(project.title)
    }

    /// PRD §6.17: "The goal is to return to the same creative desk."
    private func continueWritingSection(for document: ProjectService.Document) -> some View {
        NavigationLink(value: DocumentRoute(id: document.persistentModelID)) {
            HStack {
                Image(systemName: "arrow.uturn.forward.circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue Writing").font(.subheadline.bold())
                    Text(document.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 12) {
                if let deadline = project.deadline {
                    Text("Deadline: \(deadline.dueAt.formatted(date: .abbreviated, time: .omitted))")
                }
                Text("Total time: \(TimeFormatting.shortDuration(HomeService.totalLoggedSeconds(for: project)))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Documents").font(.headline)
                Spacer()
                Menu {
                    Button("Prose", action: addProseDocument)
                    Button("Act Outline", action: addActOutlineDocument)
                } label: {
                    Label("New Document", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
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
        DocumentService.createDocument(
            title: ordinal == 1 ? "Untitled" : "Untitled \(ordinal)",
            type: .prose,
            in: project,
            context: context
        )
        try? context.save()
    }

    private func addActOutlineDocument() {
        let ordinal = project.documents.filter { $0.documentType == .actOutline }.count + 1
        DocumentService.createDocument(
            title: ordinal == 1 ? "Act Outline" : "Act Outline \(ordinal)",
            type: .actOutline,
            in: project,
            context: context
        )
        try? context.save()
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
