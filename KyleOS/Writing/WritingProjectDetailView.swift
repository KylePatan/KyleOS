import SwiftUI
import SwiftData

/// PRD §6.4: "A writing project is a container for all related documents." Prose, Act Outline,
/// and Script documents are creatable from here — Scene Outline/Bible modes aren't standalone
/// document types (see SceneService.swift's doc comment for why Scene Outline specifically isn't
/// one). Total time reuses
/// `HomeService.totalLoggedSeconds`, the same cumulative-across-all-WorkItems calculation Home's
/// project cards already use (PRD §4.3: "include all logged work across the project").
struct WritingProjectDetailView: View {
    let project: ProjectService.Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingArchiveConfirmation = false

    /// Live @Query, not `project.documents` read inline — same class of stale-list bug confirmed
    /// for Add Scene (see SceneListView.swift's doc comment); "New Document" has the identical
    /// shape (new Document inserted, inverse-linked to `project`).
    @Query(sort: \ProjectService.Document.updatedAt, order: .reverse) private var allDocuments: [ProjectService.Document]

    private var documents: [ProjectService.Document] {
        allDocuments.filter { $0.project?.persistentModelID == project.persistentModelID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                header
                if let lastOpened = project.lastOpenedDocument {
                    continueWritingSection(for: lastOpened)
                }
                documentsSection
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
        .navigationTitle(project.title)
        .confirmationDialog(
            "Archive \"\(project.title)\"?",
            isPresented: $isShowingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Project", role: .destructive) {
                ProjectService.archive(project)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Hidden from your active Writing list, not deleted — everything in it, including any scripts, stays intact and can be restored from Archived Projects.")
        }
    }

    /// PRD §6.17: "The goal is to return to the same creative desk."
    private func continueWritingSection(for document: ProjectService.Document) -> some View {
        NavigationLink(value: DocumentRoute(id: document.persistentModelID)) {
            HStack {
                Image(systemName: "arrow.uturn.forward.circle")
                    .foregroundStyle(RetroTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue Writing").font(.subheadline.bold()).foregroundStyle(RetroTheme.primaryText)
                    Text(document.title).font(.caption).foregroundStyle(RetroTheme.secondaryText)
                }
                Spacer()
            }
            .padding(RetroTheme.controlSpacing + 4)
            .background(RetroTheme.panelBackground)
            .overlay(Rectangle().strokeBorder(RetroTheme.accent, lineWidth: RetroTheme.borderWidth))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                HStack {
                    if let projectType = project.projectType {
                        Text(projectType.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                    Spacer()
                    Picker("Status", selection: Binding(
                        get: { project.displayStatus },
                        set: { ProjectService.setStatus(project, to: $0, context: context); try? context.save() }
                    )) {
                        ForEach(ProjectService.ProjectStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .frame(width: 160)
                    Button(role: .destructive) {
                        isShowingArchiveConfirmation = true
                    } label: {
                        Label("Archive Project", systemImage: "archivebox")
                    }
                    .buttonStyle(.retro)
                }
                HStack(spacing: 12) {
                    if let deadline = project.deadline {
                        Text("Deadline: \(deadline.dueAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                    Text("Total time: \(TimeFormatting.shortDuration(HomeService.totalLoggedSeconds(for: project)))")
                }
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
            }
        }
    }

    private var documentsSection: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                HStack {
                    Text("Documents").font(.headline).foregroundStyle(RetroTheme.primaryText)
                    Spacer()
                    Menu {
                        Button("Prose", action: addProseDocument)
                        Button("Act Outline", action: addActOutlineDocument)
                        Button("Script", action: addScriptDocument)
                    } label: {
                        Label("New Document", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                if documents.isEmpty {
                    Text("No documents yet. Outline stages are never mandatory — start writing whenever you're ready.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(documents) { document in
                            NavigationLink(value: DocumentRoute(id: document.persistentModelID)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(document.title).foregroundStyle(RetroTheme.primaryText)
                                        Text("\(document.documentType.rawValue) · \(document.displayDraftLabel)")
                                            .font(.caption)
                                            .foregroundStyle(RetroTheme.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, RetroTheme.controlSpacing)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                                }
                            }
                            .buttonStyle(.plain)
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

    private func addScriptDocument() {
        let ordinal = project.documents.filter { $0.documentType == .script }.count + 1
        DocumentService.createDocument(
            title: ordinal == 1 ? "Script" : "Script \(ordinal)",
            type: .script,
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
