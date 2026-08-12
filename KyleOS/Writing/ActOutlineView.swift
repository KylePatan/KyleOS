import SwiftUI
import SwiftData

/// PRD §6.11's High-Level Act Outline: "broad story architecture... customizable, renameable,
/// reorderable, addable, and deletable. Kyle OS must not force exactly three acts." Scene
/// Outline (§6.11's next stage) and side-by-side/split view (§6.12/§6.13) are later increments.
struct ActOutlineView: View {
    let document: DocumentService.Document
    @Environment(\.modelContext) private var context

    @State private var newActTitle = ""

    private var acts: [ActService.Act] {
        ActService.acts(for: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if acts.isEmpty {
                Text("No acts yet. Kyle OS doesn't force exactly three — add as many as the story needs.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                List {
                    ForEach(acts) { act in
                        ActRow(act: act) {
                            ActService.delete(act, from: document, context: context)
                            try? context.save()
                        }
                    }
                    .onMove { source, destination in
                        ActService.reorder(document, movingFromOffsets: source, toOffset: destination)
                        try? context.save()
                    }
                }
            }
            HStack {
                TextField("New act title", text: $newActTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addAct)
                Button("Add Act", action: addAct)
                    .disabled(newActTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .navigationTitle(document.title)
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
    @State private var title: String = ""
    @State private var synopsis: String = ""

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Act title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.body.bold())
                    .onChange(of: title) {
                        ActService.rename(act, to: title)
                        try? context.save()
                    }
                TextField("What happens in this act?", text: $synopsis, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .onChange(of: synopsis) {
                        ActService.updateSynopsis(act, synopsis: synopsis)
                        try? context.save()
                    }
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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
