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

    /// Kyle (2026-08-20): "why is hackers sketch in writing but not on sketches... I feel like
    /// when you open up a sketch it should live in the sketches (not filmed yet - writing)
    /// section." Every Sketch/Short Film that's still being written (not yet finished, not a
    /// Reel) shows here too — a real column on this board, not just invisible until it graduates
    /// into production. Still visible in Writing's own list at the same time, same "additive
    /// presence, not a move" reasoning `isProductionProject` already documents.
    private var writingSketches: [ProjectService.Project] {
        allProjects.filter(SketchProductionService.isStillWriting)
    }

    private func projects(inStatus status: SketchProductionService.SketchProductionStatus) -> [ProjectService.Project] {
        sketchesOnBoard.filter { SketchProductionService.status(for: $0) == status }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sketchesOnBoard.isEmpty && writingSketches.isEmpty {
                    Text("No Sketches yet. Add one to start tracking it right away.")
                        .foregroundStyle(RetroTheme.secondaryText)
                        .padding(RetroTheme.sectionPadding)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: RetroTheme.sectionSpacing) {
                            writingColumn
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

    /// Distinct accent (`.writing`, not `.sketches`) — a deliberate visual cue that this column is
    /// still writing-phase work, not production, the same colour language Home already uses for
    /// this exact WorkItem's own `workspace`.
    private var writingColumn: some View {
        RetroPanel("Writing", accentCategory: .writing) {
            if writingSketches.isEmpty {
                Text("No sketches here.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(writingSketches) { project in
                        WritingSketchCard(project: project)
                    }
                }
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
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

/// Kyle (2026-08-20): a Sketch/Short Film still being written — simpler than `SketchCard` (no
/// production-status "Move to" menu, no Post Date, since neither applies yet). Tapping the title
/// jumps to Writing directly (`DeepLinkTarget.writingProject`, the same cross-module routing
/// `NewSketchSheet` already uses) rather than a local `NavigationLink`, since this Project isn't
/// resolvable through this board's own `sketchesOnBoard`-scoped navigation destination.
private struct WritingSketchCard: View {
    let project: ProjectService.Project
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator

    var body: some View {
        HStack {
            Button {
                navigator.navigate(to: .writingProject(project.persistentModelID))
            } label: {
                Text(project.title).font(.callout.bold()).foregroundStyle(RetroTheme.primaryText)
            }
            .buttonStyle(.plain)
            Spacer()
            Button("Mark Finished") {
                ProjectService.setStatus(project, to: .finished, context: context)
                try? context.save()
            }
            .buttonStyle(.retroCompact)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
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
