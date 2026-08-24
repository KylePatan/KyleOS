import SwiftUI
import SwiftData

/// V0.5 Sketches (PRD §9): "Sketches is primarily a production-management workspace. Writing
/// remains inside Writing. Sketches begins when a Sketch is marked Writing Finished." A finished
/// Sketch project (WritingProjectType.sketch + ProjectStatus.finished, both existing fields —
/// see SketchProductionService's doc comment) appears here automatically, grouped by its
/// production status. Short Film joined Sketch here 2026-08-20 (Kyle: "short films and sketches
/// that are finished scripts should be sent to the sketches module - because they require the
/// same sort of process of filming and posting") — see `SketchProductionService.
/// isProductionProject`, the one shared rule this and every other "does this belong in Sketches"
/// call site now reads. Same "explicit Move to… menu, not a competing drag gesture" choice as
/// JokeBoardView (CLAUDE.md §13, documented implementation choice). ClipBoardView itself moved off
/// this pattern on 2026-08-17 (Kyle: "like the home page, the clip page has to be completely
/// draggable") — not extended here since Sketches wasn't part of that request.
struct SketchBoardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator
    @Query(sort: \ProjectService.Project.updatedAt, order: .reverse) private var allProjects: [ProjectService.Project]
    @State private var path = NavigationPath()
    @State private var isPresentingNewSketch = false

    private var sketchesOnBoard: [ProjectService.Project] {
        allProjects.filter(SketchProductionService.isProductionProject)
    }

    private func projects(inStatus status: SketchProductionService.SketchProductionStatus) -> [ProjectService.Project] {
        sketchesOnBoard.filter { SketchProductionService.status(for: $0) == status }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sketchesOnBoard.isEmpty {
                    Text("No Sketches yet. Add a Reel to start tracking one right away, or mark a written Sketch's status Finished to see it here.")
                        .foregroundStyle(RetroTheme.secondaryText)
                        .padding(RetroTheme.sectionPadding)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: RetroTheme.sectionSpacing) {
                            ForEach(SketchProductionService.SketchProductionStatus.allCases, id: \.self) { status in
                                column(for: status)
                            }
                        }
                        .padding(RetroTheme.sectionPadding)
                    }
                }
            }
            .navigationTitle("Sketches")
            .background(RetroTheme.background)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let project = sketchesOnBoard.first(where: { $0.persistentModelID == id }) {
                    SketchDetailView(project: project)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewSketch = true
                    } label: {
                        Label("Add Sketch", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewSketch) {
                NewSketchSheet()
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
        let items = projects(inStatus: status)
        return RetroPanel(status.rawValue, accentCategory: .sketches) {
            if items.isEmpty {
                Text("No sketches here.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { project in
                        SketchCard(project: project, otherStatuses: SketchProductionService.SketchProductionStatus.allCases.filter { $0 != status })
                    }
                }
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
    }
}

private struct SketchCard: View {
    let project: ProjectService.Project
    let otherStatuses: [SketchProductionService.SketchProductionStatus]

    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                NavigationLink(value: project.persistentModelID) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.title).font(.callout.bold()).foregroundStyle(RetroTheme.primaryText)
                        if SketchProductionService.isReel(project) {
                            Text("REEL").font(.caption2.bold()).foregroundStyle(RetroTheme.ModuleCategory.sketches.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    openWindow(value: DetachedWindowTarget.sketchDetail(project.persistentModelID))
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.retro)
                .help("Open in a new window")
            }
            // Kyle (2026-08-18): "simplify... how clunky the information is presented" — this used
            // to be a Toggle+full-DatePicker (2 rows) calling `SketchProductionService.setPostDate`
            // directly, which also meant a Sketch's Post Date never synced to Calendar/To-Do (the
            // exact bug `ClipDetailView` had before its 2026-08-17 fix). The shared
            // `PostDateControl` (KyleOS/RetroUI/PostDateControl.swift) fixes both at once: one
            // compact pill, routed through `PostingItemService.setConfirmedPostDate`.
            PostDateControl(subject: .sketch(project))
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
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
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
