import SwiftUI

/// Reusable "Set Deadline" action (PRD §14.10/§15.1's named "Set Deadline" domain action) — shown
/// wherever a Project or individual Work Item can carry a Deadline. Kyle (2026-08-17): "Should
/// each thing created individually, as well as larger pieces (projects) have an ability to add a
/// deadline? I think that's a button and adjustment we need to add in order for the calendar
/// system to work as well as the scheduling system to boot up."
///
/// Deliberately just date + hard/soft in this pass, no label/notes fields in the popover — the
/// caller already knows what this deadline is *for* (a Project's own title, a Document's title,
/// etc.) and passes that through invisibly, keeping the control itself a single button, matching
/// Kyle's own framing ("a button"). `Deadline.notes`/`isConfirmed` exist in the model and can be
/// surfaced later if wanted; not built here since nothing asked for them yet.
struct DeadlineControl: View {
    let dueAt: Date?
    let isHard: Bool
    let onSet: (_ dueAt: Date, _ isHard: Bool) -> Void
    let onRemove: () -> Void

    @State private var isEditing = false
    @State private var draftDate = Date.now
    @State private var draftIsHard = true

    var body: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            if let dueAt {
                Button {
                    draftDate = dueAt
                    draftIsHard = isHard
                    isEditing = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isHard ? "calendar.badge.exclamationmark" : "calendar")
                        Text("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                    // RetroButtonStyle sets its own foregroundStyle on the label internally, so an
                    // outer .foregroundStyle()/.tint() on the Button itself has no effect — color
                    // the label's own content directly instead.
                    .foregroundStyle(isHard ? RetroTheme.warning : RetroTheme.primaryText)
                }
                .buttonStyle(.retro)
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.retro)
                .help("Remove deadline")
            } else {
                Button {
                    draftDate = .now
                    draftIsHard = true
                    isEditing = true
                } label: {
                    Label("Set Deadline", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.retro)
            }
        }
        .popover(isPresented: $isEditing) { editor }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
            Text(dueAt == nil ? "Set Deadline" : "Edit Deadline")
                .font(.headline)
                .foregroundStyle(RetroTheme.primaryText)
            DatePicker("Due", selection: $draftDate, displayedComponents: .date)
            Toggle("Hard deadline", isOn: $draftIsHard)
            Text(draftIsHard
                ? "Appears on Calendar as a commitment, and feeds the Scheduling Engine's urgency."
                : "A soft target — not added to Calendar, no scheduling urgency.")
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
                .frame(maxWidth: 220, alignment: .leading)
            HStack {
                Spacer()
                Button("Save") {
                    onSet(draftDate, draftIsHard)
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
}
