import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// PRD §6.6's "Prose mode for short stories and general prose" — the only in-app writing mode
/// built this increment. Script/outline/flexible long-form modes are later increments; script
/// mode specifically waits on Decision Gate A (native editor architecture). §6.18: "Writing
/// documents/stages use the universal Focus Timer" — reuses the same shared `FocusTimerController`
/// and `ActiveTimerBanner` Home already uses, via `WorkItemService.writingWorkItem`, rather than
/// building separate timing logic. Untimed writing remains allowed (targetDurationMinutes: nil).
struct ProseEditorView: View {
    let document: DocumentService.Document
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    @State private var editorText = ""
    @State private var lastSavedAt: Date?
    @State private var isShowingDraftHistory = false
    private let autosave = AutosaveController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActiveTimerBanner()
            if timerController.state == .idle {
                Button("Start Timer") {
                    guard let workItem = try? WorkItemService.writingWorkItem(for: document, context: context) else { return }
                    timerController.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: workItem.progress, context: context)
                    try? context.save()
                }
            }
            TextEditor(text: $editorText)
                .font(.system(.body, design: .serif))
                .onChange(of: editorText) {
                    autosave.scheduleSave {
                        DocumentService.updateContent(document, content: editorText)
                        try? context.save()
                        lastSavedAt = .now
                    }
                }
            statusBar
        }
        .padding()
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Start New Draft") {
                    autosave.saveImmediately {
                        DocumentService.updateContent(document, content: editorText)
                    }
                    DraftService.startNewDraft(for: document, context: context)
                    try? context.save()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingDraftHistory = true
                } label: {
                    Label("Draft History", systemImage: "clock.arrow.circlepath")
                }
                .disabled(document.drafts.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShowingDraftHistory) {
            DraftHistorySheet(document: document) { restored in
                editorText = restored
            }
        }
        .onAppear {
            editorText = document.content
        }
        .onDisappear {
            autosave.saveImmediately {
                DocumentService.updateContent(document, content: editorText)
                try? context.save()
            }
        }
    }

    /// PRD §6.20: "Writing should support clean PDF export." Autosaves first so the export
    /// always reflects the latest text, even mid-debounce.
    private func exportPDF() {
        autosave.saveImmediately {
            DocumentService.updateContent(document, content: editorText)
            try? context.save()
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = document.title
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? ExportService.exportPDF(title: document.title, body: editorText, to: url)
    }

    private var statusBar: some View {
        HStack {
            Text(document.displayDraftLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let lastSavedAt {
                Text("Saved \(lastSavedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DraftHistorySheet: View {
    let document: DocumentService.Document
    let onRestore: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Draft History").font(.headline)
            List(DraftService.drafts(for: document)) { draft in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(draft.label).font(.body.bold())
                        Spacer()
                        Text(draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(draft.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button("Restore") {
                        DraftService.restore(draft, into: document, context: context)
                        try? context.save()
                        onRestore(document.content)
                        dismiss()
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
    let document = DocumentService.createDocument(title: "Untitled", type: .prose, in: project, context: context)
    return NavigationStack {
        ProseEditorView(document: document)
    }
    .modelContainer(container)
    .environment(FocusTimerController())
}
