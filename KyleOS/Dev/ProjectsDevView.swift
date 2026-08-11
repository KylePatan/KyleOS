import SwiftUI
import SwiftData

/// Bare-bones, deliberately unstyled Project CRUD + Archive, for Foundation acceptance testing
/// only (build brief step 6). Not the real Writing/Sketches project UI — those belong to their
/// own future modules and will look nothing like this.
struct ProjectsDevView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<ProjectService.Project> { !$0.isArchived }, sort: \.createdAt)
    private var activeProjects: [ProjectService.Project]

    @Query(filter: #Predicate<ProjectService.Project> { $0.isArchived }, sort: \.createdAt)
    private var archivedProjects: [ProjectService.Project]

    @State private var newProjectTitle = ""
    @State private var renamingProjectID: PersistentIdentifier?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            developerBanner
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    createSection
                    section(title: "Active", projects: activeProjects, isArchived: false)
                    if !archivedProjects.isEmpty {
                        section(title: "Archived", projects: archivedProjects, isArchived: true)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Projects (Dev)")
    }

    private var developerBanner: some View {
        Label(
            "Developer screen — Foundation verification only. Not part of the PRD's navigation; removed once a real module owns Project CRUD.",
            systemImage: "wrench.and.screwdriver"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15))
    }

    private var createSection: some View {
        HStack {
            TextField("New project title", text: $newProjectTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(createProject)
            Button("Add", action: createProject)
                .disabled(newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func section(title: String, projects: [ProjectService.Project], isArchived: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(projects.count))").font(.headline)
            if projects.isEmpty {
                Text("None yet.").foregroundStyle(.secondary)
            }
            ForEach(projects) { project in
                projectRow(project, isArchived: isArchived)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func projectRow(_ project: ProjectService.Project, isArchived: Bool) -> some View {
        if renamingProjectID == project.persistentModelID {
            HStack {
                TextField("Title", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitRename(project) }
                Button("Save") { commitRename(project) }
                Button("Cancel") { renamingProjectID = nil }
            }
        } else {
            HStack {
                VStack(alignment: .leading) {
                    Text(project.title)
                    Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rename") {
                    renamingProjectID = project.persistentModelID
                    renameText = project.title
                }
                if isArchived {
                    Button("Restore") {
                        ProjectService.restore(project)
                        save()
                    }
                } else {
                    Button("Archive", role: .destructive) {
                        ProjectService.archive(project)
                        save()
                    }
                }
            }
        }
    }

    private func createProject() {
        let title = newProjectTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        ProjectService.createProject(title: title, in: context)
        newProjectTitle = ""
        save()
    }

    private func commitRename(_ project: ProjectService.Project) {
        let title = renameText.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        ProjectService.rename(project, to: title)
        renamingProjectID = nil
        save()
    }

    private func save() {
        try? context.save()
    }
}

#Preview {
    ProjectsDevView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
