import SwiftUI

/// Compact Post Date editor — icon + short date pill, shared by every board card that carries a
/// Post Date (Clips, Sketches). Kyle (2026-08-18): "simplify... how clunky the information is
/// presented" — same motivation as `DeadlineControl.compact`/`RetroButtonStyle.compact`, first
/// built for `ClipBoardView`, promoted here so `SketchBoardView` reuses it instead of duplicating
/// it (and instead of the Toggle+full-DatePicker shape it had before, which was both wordier
/// *and*, on both the Sketch board and `SketchDetailView`, called `SketchProductionService.
/// setPostDate` directly — bypassing `PostingItemService` and its Calendar/To-Do sync entirely,
/// the exact same bug `ClipDetailView`'s old Post Date toggle had before it was fixed on
/// 2026-08-17). Routing every caller through `PostingItemService.setConfirmedPostDate` here fixes
/// that for Sketches too, for free.
///
/// Deliberately its own small control rather than reusing `DeadlineControl` — that control exposes
/// a hard/soft toggle that `setConfirmedPostDate` ignores (a Post Date is always hard/locked).
struct PostDateControl: View {
    enum Subject {
        case clip(ClipService.Clip)
        case sketch(PostingItemService.Project)
    }

    let subject: Subject
    @Environment(\.modelContext) private var context

    @State private var isEditing = false
    @State private var draftDate = Date.now

    private var currentDate: Date? {
        switch subject {
        case .clip(let clip): return clip.postDate
        case .sketch(let project): return SketchProductionService.postDate(for: project)
        }
    }

    private var recommended: Date? {
        currentDate == nil ? PostingItemService.recommendedPostDate(in: context) : nil
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                draftDate = currentDate ?? recommended ?? .now
                isEditing = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "paperplane")
                    if let currentDate {
                        Text(currentDate.formatted(.dateTime.month(.abbreviated).day()))
                    }
                }
                .foregroundStyle(RetroTheme.primaryText)
            }
            .buttonStyle(.retroCompact)
            .help(currentDate.map { "Post \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Set post date")

            if let recommended {
                Button {
                    savePostDate(recommended)
                } label: {
                    Text(recommended.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .underline()
                }
                .buttonStyle(.plain)
                .foregroundStyle(RetroTheme.accent)
                .help("Recommended: \(recommended.formatted(date: .abbreviated, time: .omitted)) — tap to set")
            }
        }
        .popover(isPresented: $isEditing) { editor }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
            Text("Post Date").font(.headline).foregroundStyle(RetroTheme.primaryText)
            DatePicker("Date", selection: $draftDate, displayedComponents: .date)
            Text("Static once set — appears on Calendar and To Do, and won't move unless changed here.")
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
                .frame(maxWidth: 220, alignment: .leading)
            HStack {
                if currentDate != nil {
                    Button(role: .destructive) {
                        savePostDate(nil)
                        isEditing = false
                    } label: {
                        Text("Remove")
                    }
                    .buttonStyle(.retro)
                }
                Spacer()
                Button("Save") {
                    savePostDate(draftDate)
                    isEditing = false
                }
                .buttonStyle(.retroProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RetroTheme.sectionPadding)
        .frame(width: 260)
        .background(RetroTheme.panelBackground)
    }

    private func savePostDate(_ date: Date?) {
        switch subject {
        case .clip(let clip):
            let item = PostingItemService.findOrCreate(for: clip, context: context)
            PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        case .sketch(let project):
            let item = PostingItemService.findOrCreate(for: project, context: context)
            PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        }
        try? context.save()
    }
}
