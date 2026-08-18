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
    /// Kyle (2026-08-17): once a screen shows more than one deadline (e.g. a Clip's separate
    /// Editing and Subtitling deadlines), a generic "Set Deadline" on both is ambiguous — `nil`
    /// preserves the original generic wording exactly, unchanged, for every call site that
    /// existed before this.
    var label: String? = nil
    let dueAt: Date?
    let isHard: Bool
    let onSet: (_ dueAt: Date, _ isHard: Bool) -> Void
    let onRemove: () -> Void

    /// Kyle (2026-08-18): "simplify... just when presenting the information, not a full re-do of
    /// the aesthetic." Board cards (several deadlines stacked next to other controls) need a much
    /// smaller footprint than a full-sentence button — compact mode swaps the wordy "Set Editing
    /// Deadline"/"Editing due Aug 20" text for an identifying icon (`compactIcon`) + a short date,
    /// moves Remove into the popover instead of a second always-visible button, and relies on
    /// `.help()` for the full text a normal button would have spelled out. Opt-in — every existing
    /// call site (ClipDetailView, SketchDetailView, etc.) is unchanged.
    var compact: Bool = false
    /// Only meaningful when `compact` is true — the icon identifying *what* this deadline is for
    /// (e.g. "pencil" for an Editing deadline), since compact mode drops the descriptive label
    /// text that normally conveys that.
    var compactIcon: String = "calendar"

    @State private var isEditing = false
    @State private var draftDate = Date.now
    @State private var draftIsHard = true

    private var setButtonText: String {
        label.map { "Set \($0) Deadline" } ?? "Set Deadline"
    }

    private var dueButtonText: String {
        guard let dueAt else { return "" }
        let formatted = dueAt.formatted(date: .abbreviated, time: .omitted)
        return label.map { "\($0) due \(formatted)" } ?? "Due \(formatted)"
    }

    private var editorTitle: String {
        let action = dueAt == nil ? "Set" : "Edit"
        return label.map { "\(action) \($0) Deadline" } ?? "\(action) Deadline"
    }

    private var compactHelpText: String {
        guard let dueAt else { return setButtonText }
        return dueButtonText
    }

    var body: some View {
        Group {
            if compact {
                compactBody
            } else {
                fullBody
            }
        }
        .popover(isPresented: $isEditing) { editor }
    }

    private var fullBody: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            if let dueAt {
                Button {
                    draftDate = dueAt
                    draftIsHard = isHard
                    isEditing = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isHard ? "calendar.badge.exclamationmark" : "calendar")
                        Text(dueButtonText)
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
                    Label(setButtonText, systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.retro)
            }
        }
    }

    private var compactBody: some View {
        Button {
            draftDate = dueAt ?? .now
            draftIsHard = dueAt == nil ? true : isHard
            isEditing = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: compactIcon)
                if let dueAt {
                    Text(dueAt.formatted(.dateTime.month(.abbreviated).day()))
                }
            }
            .foregroundStyle(dueAt == nil ? RetroTheme.primaryText : (isHard ? RetroTheme.warning : RetroTheme.primaryText))
        }
        .buttonStyle(.retroCompact)
        .help(compactHelpText)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
            Text(editorTitle)
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
                if compact, dueAt != nil {
                    Button(role: .destructive) {
                        onRemove()
                        isEditing = false
                    } label: {
                        Text("Remove")
                    }
                    .buttonStyle(.retro)
                }
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
