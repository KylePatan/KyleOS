import SwiftUI
import SwiftData

/// Bare-bones Document create/edit + autosave verification, for Foundation acceptance testing
/// only (build brief steps 7-8: "basic Document persistence/editor" + "add autosave"). Not the
/// real Writing editor — structured Script Blocks and screenplay formatting are Decision Gate A
/// (V0.2), not decided here. Plain text content only.
struct DocumentsDevView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<ProjectService.Project> { !$0.isArchived }, sort: \.createdAt)
    private var activeProjects: [ProjectService.Project]

    @Query private var allDocuments: [DocumentService.Document]

    @State private var selectedProjectID: PersistentIdentifier?
    @State private var selectedDocumentID: PersistentIdentifier?
    @State private var newDocumentTitle = ""
    @State private var newDocumentType: DocumentService.DocumentType = .notes
    @State private var editorText = ""
    @State private var lastSavedAt: Date?

    private let autosave = AutosaveController(delay: 1.0)

    private var selectedProject: ProjectService.Project? {
        activeProjects.first { $0.persistentModelID == selectedProjectID }
    }

    private var documentsForSelectedProject: [DocumentService.Document] {
        guard let selectedProjectID else { return [] }
        return allDocuments
            .filter { $0.project?.persistentModelID == selectedProjectID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedDocument: DocumentService.Document? {
        allDocuments.first { $0.persistentModelID == selectedDocumentID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            developerBanner
            Divider()
            if activeProjects.isEmpty {
                Text("Create a project in the Projects dev screen first.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                HSplitView {
                    sidebar
                        .frame(minWidth: 220, maxWidth: 280)
                    editor
                        .frame(minWidth: 400, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Documents (Dev)")
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = activeProjects.first?.persistentModelID
            }
        }
    }

    private var developerBanner: some View {
        Label(
            "Developer screen — Foundation verification only. Plain text only; the real structured screenplay editor is a V0.2 decision (Decision Gate A).",
            systemImage: "wrench.and.screwdriver"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Project", selection: $selectedProjectID) {
                ForEach(activeProjects) { project in
                    Text(project.title).tag(project.persistentModelID as PersistentIdentifier?)
                }
            }
            .labelsHidden()
            .onChange(of: selectedProjectID) {
                selectedDocumentID = nil
                editorText = ""
            }

            HStack {
                TextField("New document title", text: $newDocumentTitle)
                    .textFieldStyle(.roundedBorder)
                Picker("Type", selection: $newDocumentType) {
                    ForEach(DocumentService.DocumentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }
            Button("Add Document", action: createDocument)
                .disabled(newDocumentTitle.trimmingCharacters(in: .whitespaces).isEmpty || selectedProject == nil)

            Divider()

            List(documentsForSelectedProject, selection: $selectedDocumentID) { document in
                VStack(alignment: .leading) {
                    Text(document.title)
                    Text(document.documentType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(document.persistentModelID as PersistentIdentifier?)
            }
        }
        .padding()
        .onChange(of: selectedDocumentID) {
            editorText = selectedDocument?.content ?? ""
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let document = selectedDocument {
                Text(document.title).font(.headline)
                TextEditor(text: $editorText)
                    .font(.body)
                    .onChange(of: editorText) {
                        autosave.scheduleSave {
                            DocumentService.updateContent(document, content: editorText)
                            try? context.save()
                            lastSavedAt = .now
                        }
                    }
                if let lastSavedAt {
                    Text("Saved \(lastSavedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select or create a document.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding()
    }

    private func createDocument() {
        guard let project = selectedProject else { return }
        let title = newDocumentTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let document = DocumentService.createDocument(title: title, type: newDocumentType, in: project, context: context)
        try? context.save()
        newDocumentTitle = ""
        selectedDocumentID = document.persistentModelID
        editorText = ""
    }
}

#Preview {
    DocumentsDevView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
