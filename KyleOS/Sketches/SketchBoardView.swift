import SwiftUI
import SwiftData

/// V0.5 Sketches (PRD §9): "Sketches is primarily a production-management workspace. Writing
/// remains inside Writing. Sketches begins when a Sketch is marked Writing Finished." A finished
/// Sketch project (WritingProjectType.sketch + ProjectStatus.finished, both existing fields —
/// see SketchProductionService's doc comment) appears here automatically, grouped by its
/// production status. Same "explicit Move to… menu, not a competing drag gesture" choice as
/// JokeBoardView/ClipBoardView (CLAUDE.md §13, documented implementation choice).
struct SketchBoardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator
    @Query(sort: \ProjectService.Project.updatedAt, order: .reverse) private var allProjects: [ProjectService.Project]
    @State private var path = NavigationPath()

    private var finishedSketches: [ProjectService.Project] {
        allProjects.filter { $0.projectType == .sketch && $0.status == .finished && !$0.isArchived }
    }

    private func projects(inStatus status: SketchProductionService.SketchProductionStatus) -> [ProjectService.Project] {
        finishedSketches.filter { SketchProductionService.status(for: $0) == status }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(SketchProductionService.SketchProductionStatus.allCases, id: \.self) { status in
                        column(for: status)
                    }
                }
                .padding()
            }
            .navigationTitle("Sketches")
            .overlay {
                if finishedSketches.isEmpty {
                    Text("No finished Sketches yet. Mark a Sketch project's Writing status Finished to see it here.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let project = finishedSketches.first(where: { $0.persistentModelID == id }) {
                    SketchDetailView(project: project)
                }
            }
        }
        .task(id: navigator.pendingTarget) { consumePendingTarget() }
    }

    private func consumePendingTarget() {
        guard case .sketchProject(let id) = navigator.pendingTarget else { return }
        path.append(id)
        navigator.pendingTarget = nil
    }

    private func column(for status: SketchProductionService.SketchProductionStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.rawValue).font(.headline)
            let items = projects(inStatus: status)
            if items.isEmpty {
                Text("No sketches here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(items) { project in
                        SketchCard(project: project, otherStatuses: SketchProductionService.SketchProductionStatus.allCases.filter { $0 != status })
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 160, idealHeight: CGFloat(items.count) * 60 + 20)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
    }
}

private struct SketchCard: View {
    let project: ProjectService.Project
    let otherStatuses: [SketchProductionService.SketchProductionStatus]

    @Environment(\.modelContext) private var context
    @State private var hasPostDate = false
    @State private var postDate = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            NavigationLink(value: project.persistentModelID) {
                Text(project.title).font(.callout.bold())
            }
            Toggle("Post date", isOn: $hasPostDate)
                .font(.caption)
                .onChange(of: hasPostDate) {
                    SketchProductionService.setPostDate(for: project, date: hasPostDate ? postDate : nil, context: context)
                    try? context.save()
                }
            if hasPostDate {
                DatePicker("", selection: $postDate, displayedComponents: .date)
                    .labelsHidden()
                    .font(.caption)
                    .onChange(of: postDate) {
                        SketchProductionService.setPostDate(for: project, date: postDate, context: context)
                        try? context.save()
                    }
            }
            Menu("Move to") {
                ForEach(otherStatuses, id: \.self) { status in
                    Button(status.rawValue) {
                        SketchProductionService.changeStatus(for: project, to: status, context: context)
                        try? context.save()
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(.caption)
        }
        .padding(.vertical, 4)
        .onAppear {
            if let date = SketchProductionService.postDate(for: project) {
                postDate = date
                hasPostDate = true
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
    SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
    return NavigationStack {
        SketchBoardView()
    }
    .modelContainer(container)
    .environment(AppNavigationController())
}
