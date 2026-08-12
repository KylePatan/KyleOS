import SwiftUI
import SwiftData

/// V0.2 Writing's first increment (PRD §6.3): shows active, finished, and idea/not-started
/// Writing Projects. Only the container/list layer + a prose editor exist yet — script mode,
/// layered outlining, and split view are later increments (Decision Gate A governs the script
/// editor specifically, see docs/PHASE_DECISION_REGISTER.md).
struct WritingHomeView: View {
    // SwiftData's #Predicate can't reliably evaluate a keypath into an enum-typed property
    // (confirmed live: even a plain `!= nil` check on `projectType` crashed with "keypath
    // projectType not found in entity Project") — filter on the safe field (isArchived) in the
    // predicate, then filter the enum-typed field in-memory, same workaround already used in
    // PlannedSessionService.upcoming().
    @Query(filter: #Predicate<ProjectService.Project> { !$0.isArchived }, sort: \.updatedAt)
    private var allActiveProjects: [ProjectService.Project]

    private var allWritingProjects: [ProjectService.Project] {
        allActiveProjects.filter { $0.projectType != nil }
    }

    @State private var isPresentingNewProject = false
    @State private var path = NavigationPath()

    private var grouped: [(ProjectService.ProjectStatus, [ProjectService.Project])] {
        let byStatus = Dictionary(grouping: allWritingProjects) { $0.displayStatus }
        return [ProjectService.ProjectStatus.active, .idea, .onHold, .finished].compactMap { status in
            guard let projects = byStatus[status], !projects.isEmpty else { return nil }
            return (status, projects.sorted { $0.updatedAt > $1.updatedAt })
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if allWritingProjects.isEmpty {
                    ContentUnavailableView(
                        "No Writing Projects Yet",
                        systemImage: "pencil.and.outline",
                        description: Text("Create a TV Pilot, Screenplay, Short Story, or other Writing project to get started.")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.0) { status, projects in
                            Section(status.rawValue) {
                                ForEach(projects) { project in
                                    NavigationLink(value: ProjectRoute(id: project.persistentModelID)) {
                                        WritingProjectRow(project: project)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Writing")
            .navigationDestination(for: ProjectRoute.self) { route in
                if let project = allWritingProjects.first(where: { $0.persistentModelID == route.id }) {
                    WritingProjectDetailView(project: project)
                }
            }
            .navigationDestination(for: DocumentRoute.self) { route in
                if let document = allWritingProjects.flatMap(\.documents).first(where: { $0.persistentModelID == route.id }) {
                    ProseEditorView(document: document)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewProject = true
                    } label: {
                        Label("New Writing Project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewProject) {
                NewWritingProjectSheet()
            }
        }
    }
}

private struct WritingProjectRow: View {
    let project: ProjectService.Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.title).font(.body)
            HStack(spacing: 6) {
                if let projectType = project.projectType {
                    Text(projectType.rawValue)
                }
                Text("Edited \(project.updatedAt.formatted(date: .abbreviated, time: .omitted))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WritingHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
