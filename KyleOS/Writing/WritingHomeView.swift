import SwiftUI
import SwiftData

/// V0.2 Writing (PRD §6.3): shows active, finished, and idea/not-started Writing Projects.
/// Container/list layer, prose editor, Act Outline (§6.11), Scene Outline (§6.11, a drill-down
/// of an Act — see SceneService.swift), Focus Timer, PDF export, Workspace Restoration, and the
/// Script Editor (Decision Gate A, resolved with Kyle — see ScriptEditorView.swift) exist so far.
/// Side-by-side split view (§6.12/§6.13) is a later increment.
struct WritingHomeView: View {
    @Environment(AppNavigationController.self) private var navigator
    @Environment(\.modelContext) private var context

    // SwiftData's #Predicate can't reliably evaluate a keypath into an enum-typed property
    // (confirmed live: even a plain `!= nil` check on `projectType` crashed with "keypath
    // projectType not found in entity Project") — filter on the safe field (isArchived) in the
    // predicate, then filter the enum-typed field in-memory, same workaround already used in
    // PlannedSessionService.upcoming().
    @Query(filter: #Predicate<ProjectService.Project> { !$0.isArchived }, sort: \.updatedAt)
    private var allActiveProjects: [ProjectService.Project]

    @Query(filter: #Predicate<ProjectService.Project> { $0.isArchived }, sort: \.updatedAt, order: .reverse)
    private var allArchivedProjects: [ProjectService.Project]

    private var allWritingProjects: [ProjectService.Project] {
        allActiveProjects.filter { $0.projectType != nil }
    }

    private var archivedWritingProjects: [ProjectService.Project] {
        allArchivedProjects.filter { $0.projectType != nil }
    }

    @State private var isPresentingNewProject = false
    @State private var isPresentingArchivedProjects = false
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                            ForEach(grouped, id: \.0) { status, projects in
                                RetroPanel(status.rawValue) {
                                    VStack(spacing: 0) {
                                        ForEach(projects) { project in
                                            NavigationLink(value: ProjectRoute(id: project.persistentModelID)) {
                                                WritingProjectRow(project: project)
                                            }
                                            .buttonStyle(.plain)
                                            // Kyle (2026-08-20, real use): "'P' and 'test'...
                                            // aren't real and from the writing page i should be
                                            // able to delete things from it." Archive already
                                            // existed (WritingProjectDetailView's own button);
                                            // this adds Delete for junk/test content, right on
                                            // the list row so drilling in isn't required.
                                            .archiveDeleteContextMenu(
                                                onArchive: {
                                                    ProjectService.archive(project)
                                                    try? context.save()
                                                },
                                                onDelete: {
                                                    ProjectService.delete(project, context: context)
                                                    try? context.save()
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(RetroTheme.sectionPadding)
                    }
                    .background(RetroTheme.background)
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
                    switch document.documentType {
                    case .actOutline:
                        ActOutlineView(document: document)
                    case .script:
                        ScriptEditorView(document: document)
                    default:
                        ProseEditorView(document: document)
                    }
                }
            }
            .navigationDestination(for: ActRoute.self) { route in
                if let act = allWritingProjects.flatMap(\.documents).flatMap(\.acts).first(where: { $0.persistentModelID == route.id }) {
                    SceneListView(act: act)
                }
            }
            .toolbar {
                // Kyle (2026-08-17): "I want the + button on the top right of the screen for
                // writing rather than top middle. Was hard to find." Reproduced: mixing a
                // `.secondaryAction` item with a `.primaryAction` item pushed both toward the
                // window's horizontal center instead of the trailing edge Home's single
                // `.primaryAction` toolbar button (QuickAddButton) already renders at correctly.
                // Grouping both under one `.primaryAction` `ToolbarItemGroup` keeps them together
                // as a trailing-aligned block instead.
                ToolbarItemGroup(placement: .primaryAction) {
                    if !archivedWritingProjects.isEmpty {
                        Button {
                            isPresentingArchivedProjects = true
                        } label: {
                            Label("Archived Projects (\(archivedWritingProjects.count))", systemImage: "archivebox")
                        }
                    }
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
            .sheet(isPresented: $isPresentingArchivedProjects) {
                ArchivedWritingProjectsSheet()
            }
        }
        .task(id: navigator.pendingTarget) { consumePendingTarget() }
    }

    /// Kyle (2026-08-15): clicking a project card on Home should land here, on that project.
    /// `.task(id:)` re-runs whenever `pendingTarget` changes, including the moment this view
    /// first appears already carrying one (the sidebar-switch and the target are set together in
    /// `AppNavigationController.navigate(to:)`).
    private func consumePendingTarget() {
        guard case .writingProject(let id) = navigator.pendingTarget else { return }
        path.append(ProjectRoute(id: id))
        navigator.pendingTarget = nil
    }
}

private struct WritingProjectRow: View {
    let project: ProjectService.Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.title).font(.body.bold()).foregroundStyle(RetroTheme.primaryText)
            HStack(spacing: 6) {
                if let projectType = project.projectType {
                    Text(projectType.rawValue)
                }
                Text("Edited \(project.updatedAt.formatted(date: .abbreviated, time: .omitted))")
            }
            .font(.caption)
            .foregroundStyle(RetroTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
    }
}

/// Kyle (2026-08-16): "I don't want 'untitled TV pilot' and its not real, and i can't seem to
/// delete it. We need to fix it so everything you create, you have an option to remove." Archive
/// (CLAUDE.md §5: never a hard delete for irreplaceable creative work) is the removal itself —
/// `WritingProjectDetailView`'s "Archive Project" button; this sheet is the other half, so
/// archiving is never a one-way trip the user can't see or undo themselves.
private struct ArchivedWritingProjectsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Own live @Query rather than taking the list as a passed-in array — a plain array snapshot
    /// wouldn't shrink when Restore is tapped inside this same sheet session (the exact class of
    /// stale-list bug behind the Add Scene fix elsewhere this session; see SceneListView.swift).
    @Query(filter: #Predicate<ProjectService.Project> { $0.isArchived }, sort: \.updatedAt, order: .reverse)
    private var allArchivedProjects: [ProjectService.Project]

    private var projects: [ProjectService.Project] {
        allArchivedProjects.filter { $0.projectType != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Archived Projects").font(.headline).foregroundStyle(RetroTheme.primaryText)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.retroProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(RetroTheme.sectionPadding)
            if projects.isEmpty {
                Text("Nothing archived.").foregroundStyle(RetroTheme.secondaryText).padding(RetroTheme.sectionPadding)
            } else {
                VStack(spacing: 0) {
                    ForEach(projects) { project in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title).foregroundStyle(RetroTheme.primaryText)
                                if let projectType = project.projectType {
                                    Text(projectType.rawValue).font(.caption).foregroundStyle(RetroTheme.secondaryText)
                                }
                            }
                            Spacer()
                            Button("Restore") {
                                ProjectService.restore(project)
                                try? context.save()
                            }
                            .buttonStyle(.retro)
                        }
                        .padding(.horizontal, RetroTheme.sectionPadding)
                        .padding(.vertical, RetroTheme.controlSpacing)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 380, minHeight: 300)
        .background(RetroTheme.panelBackground)
    }
}

#Preview {
    WritingHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(AppNavigationController())
}
