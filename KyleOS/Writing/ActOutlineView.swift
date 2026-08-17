import SwiftUI
import SwiftData

/// PRD §6.11's High-Level Act Outline: "broad story architecture... customizable, renameable,
/// reorderable, addable, and deletable. Kyle OS must not force exactly three acts." Scene
/// Outline (§6.11's next stage) and side-by-side/split view (§6.12/§6.13) are later increments.
struct ActOutlineView: View {
    let document: DocumentService.Document
    @Environment(\.modelContext) private var context

    @State private var newActTitle = ""

    /// Live @Query, not `ActService.acts(for: document)` (which reads `document.acts` off this
    /// plain-held `document` reference) — same class of stale-list bug confirmed for Add Scene
    /// (see SceneListView.swift's doc comment); "Add Act" has the identical shape (new Act
    /// inserted, inverse-linked to `document`), so it silently failed to refresh the same way.
    @Query(sort: \ActService.Act.order) private var allActs: [ActService.Act]

    private var acts: [ActService.Act] {
        allActs.filter { $0.document?.persistentModelID == document.persistentModelID }
    }

    /// Kyle (2026-08-17): "even smaller things deserve deadlines including 'act outline'. Because
    /// once we have a deadline for that - we can move on. While the big project itself... has a
    /// hard deadline to finish EVERYTHING." So an Act Outline Document's own deadline is distinct
    /// from — and typically earlier/softer than — its parent Project's. Same lazy-WorkItem pattern
    /// as ProseEditorView.
    @Query private var allWorkItems: [WorkItemService.WorkItem]

    private var workItem: WorkItemService.WorkItem? {
        allWorkItems.first { $0.document?.persistentModelID == document.persistentModelID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            HStack {
                Spacer()
                DeadlineControl(
                    dueAt: workItem?.deadline?.dueAt,
                    isHard: workItem?.deadline?.isHard ?? true,
                    onSet: { dueAt, isHard in
                        guard let resolvedWorkItem = try? WorkItemService.writingWorkItem(for: document, context: context) else { return }
                        DeadlineService.setDeadline(for: resolvedWorkItem, label: document.title, dueAt: dueAt, isHard: isHard, context: context)
                        try? context.save()
                    },
                    onRemove: {
                        guard let workItem else { return }
                        DeadlineService.removeDeadline(for: workItem, context: context)
                        try? context.save()
                    }
                )
            }
            if acts.isEmpty {
                Text("No acts yet. Kyle OS doesn't force exactly three — add as many as the story needs.")
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                RetroPanel("Acts") {
                    List {
                        ForEach(acts) { act in
                            ActRow(act: act) {
                                ActService.delete(act, from: document, context: context)
                                try? context.save()
                            }
                            .listRowBackground(RetroTheme.panelBackground)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                        }
                        .onMove { source, destination in
                            ActService.reorder(document, movingFromOffsets: source, toOffset: destination)
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: max(100, CGFloat(acts.count) * 90 + 20))
                }
            }
            RetroPanel {
                HStack {
                    TextField("New act title", text: $newActTitle)
                        .retroInputStyle()
                        .onSubmit(addAct)
                    Button("Add Act", action: addAct)
                        .buttonStyle(.retroProminent)
                        .disabled(newActTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(RetroTheme.sectionPadding)
        .background(RetroTheme.background)
        .navigationTitle(document.title)
        .onAppear {
            if let project = document.project {
                ProjectService.recordLastOpenedDocument(document, in: project)
                try? context.save()
            }
        }
    }

    private func addAct() {
        let title = newActTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        ActService.createAct(title: title, in: document, context: context)
        try? context.save()
        newActTitle = ""
    }
}

private struct ActRow: View {
    let act: ActService.Act
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @State private var title: String = ""
    @State private var synopsis: String = ""

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Act title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.body.bold())
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: title) {
                        ActService.rename(act, to: title)
                        try? context.save()
                    }
                TextField("What happens in this act?", text: $synopsis, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: synopsis) {
                        ActService.updateSynopsis(act, synopsis: synopsis)
                        try? context.save()
                    }
                NavigationLink(value: ActRoute(id: act.persistentModelID)) {
                    Text("\(act.scenes.count) scene\(act.scenes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.accent)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                openWindow(value: DetachedWindowTarget.actScenes(act.persistentModelID))
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.retro)
            .help("Open Scenes in a new window")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.retro)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .onAppear {
            title = act.title
            synopsis = act.synopsis
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
    let document = DocumentService.createDocument(title: "Act Outline", type: .actOutline, in: project, context: context)
    ActService.createAct(title: "Act One", synopsis: "Our hero arrives.", in: document, context: context)
    return NavigationStack {
        ActOutlineView(document: document)
    }
    .modelContainer(container)
}
