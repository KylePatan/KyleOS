import SwiftUI
import SwiftData

/// PRD §10: "Home should contain a dedicated Post It section so content publishing does not
/// disappear among writing/editing tasks." Ingests exactly the two content types the PRD names —
/// Clips and finished Sketch Projects (§9.8: "counts toward the same overall posting cadence as
/// Clips"; §10.4: "shared across Clips and Sketches") — Stand Up produces no postable content.
/// "Sketch Projects" now also covers finished Short Films (`SketchProductionService.
/// isProductionProject`, 2026-08-20) since both go through the same filming/posting pipeline.
/// Reuses that shared predicate directly against `@Query`d arrays rather than the context-based
/// `finishedSketchProjects(in:)` helper, matching every other Home widget's "query shared
/// underlying data" pattern (a fresh context fetch inside a computed property wouldn't stay live).
struct PostItView: View {
    @Environment(\.modelContext) private var context
    @Query private var allClips: [PostingItemService.Clip]
    @Query private var allProjects: [PostingItemService.Project]
    @Query private var allSettings: [SettingsService.AppSettings]

    @State private var editingRow: PostItRow?
    @State private var cadenceTarget = 3

    private var finishedSketchProjects: [PostingItemService.Project] {
        allProjects.filter(SketchProductionService.isProductionProject)
    }

    /// Kyle (2026-08-20, real use): "in clips there is still an airplane clip to be posted even
    /// though i've cleared it." Real bug: this used to only filter out `.notReady` rows, so once
    /// something was actually marked Posted it stayed in the "Ready to Post" list forever — the
    /// summary counts above (`readyToPostCount`/`scheduledThisWeekCount`) already excluded
    /// `.posted` correctly, but the rendered row list underneath them didn't, so the panel's own
    /// title ("Ready to Post") and its own contents disagreed with each other.
    private var rows: [PostItRow] {
        let clipRows = allClips.map { PostItRow(content: .clip($0)) }
        let sketchRows = finishedSketchProjects.map { PostItRow(content: .sketch($0)) }
        return (clipRows + sketchRows)
            .filter { $0.displayStatus != .notReady && $0.displayStatus != .posted }
            .sorted {
                switch ($0.confirmedPostDate, $1.confirmedPostDate) {
                case (nil, nil): return $0.title < $1.title
                case (nil, _): return false
                case (_, nil): return true
                case let (a?, b?): return a < b
                }
            }
    }

    /// PRD §10.3: "Ready to Post: 5 / Scheduled This Week: 3 / Unscheduled Ready Content: 2."
    private var readyToPostCount: Int { rows.filter { $0.displayStatus != .posted }.count }
    private var scheduledThisWeekCount: Int {
        let weekFromNow = Date(timeIntervalSinceNow: 86400 * 7)
        return rows.filter {
            guard let date = $0.confirmedPostDate else { return false }
            return $0.displayStatus != .posted && date <= weekFromNow
        }.count
    }
    private var unscheduledReadyCount: Int {
        rows.filter { $0.displayStatus == .ready && $0.confirmedPostDate == nil }.count
    }

    /// PRD §8.8/§10.4: "Kyle OS should suggest open posting dates and avoid unnecessary
    /// clustering... shared across Clips and Sketches" — the confirmed-date pool spans both
    /// content types, matching the shared posting calendar the PRD describes.
    private var suggestedDates: [Date] {
        let confirmedDates = rows.compactMap { $0.displayStatus != .posted ? $0.confirmedPostDate : nil }
        return PostingCadenceService.suggestedDates(target: cadenceTarget, confirmedDates: confirmedDates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            RetroPanel {
                VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                    summaryBar
                    Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                    cadenceSection
                }
            }
            if rows.isEmpty {
                Text("Nothing ready to post yet. Finish editing a Clip or Sketch to see it here.")
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                RetroPanel("Ready to Post") {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            rowView(row)
                        }
                    }
                }
            }
        }
        .padding(RetroTheme.sectionPadding)
        .sheet(item: $editingRow) { row in
            PostItRowSheet(row: row)
        }
        .onAppear { cadenceTarget = allSettings.first?.displayPostsPerWeekTarget ?? 3 }
    }

    private var cadenceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Stepper("Weekly posting goal: \(cadenceTarget)", value: $cadenceTarget, in: 0...14)
                    .onChange(of: cadenceTarget) { saveCadenceTarget() }
                    .foregroundStyle(RetroTheme.primaryText)
            }
            if !suggestedDates.isEmpty {
                Text("Suggested post dates: " + suggestedDates.prefix(4).map { $0.formatted(.dateTime.month().day()) }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
        }
    }

    private func saveCadenceTarget() {
        guard let settings = allSettings.first else { return }
        SettingsService.updatePostsPerWeekTarget(settings, to: cadenceTarget)
        try? context.save()
    }

    private var summaryBar: some View {
        HStack(spacing: RetroTheme.sectionSpacing) {
            summaryStat(label: "Ready to Post", count: readyToPostCount)
            summaryStat(label: "Scheduled This Week", count: scheduledThisWeekCount)
            summaryStat(label: "Unscheduled Ready", count: unscheduledReadyCount)
        }
    }

    private func summaryStat(label: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(RetroTheme.secondaryText)
            Text("\(count)").font(.headline).foregroundStyle(RetroTheme.primaryText)
        }
    }

    private func rowView(_ row: PostItRow) -> some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            statusDot(row.displayStatus)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.callout).foregroundStyle(RetroTheme.primaryText)
                // §0's category colour language — a Clip's "Clip" label reads pink/red, a
                // Sketch's "Sketch" label reads green, matching those workspaces everywhere else.
                Text(row.subtitle).font(.caption2).foregroundStyle(row.category.accent)
            }
            Spacer()
            if let date = row.confirmedPostDate {
                Text(date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
            Text(row.displayStatus.rawValue)
                .font(.caption)
                .foregroundStyle(color(for: row.displayStatus))
            Button("Edit") { editingRow = row }
                .buttonStyle(.retro)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        // Kyle (2026-08-20): "the things on 'home' should be removeable." A Clip has no archive
        // state of its own (only its Source does), so only Delete is offered there; a Sketch
        // Project can be archived like any other Project.
        .archiveDeleteContextMenu(
            onArchive: archiveAction(for: row),
            onDelete: { remove(row) }
        )
    }

    private func archiveAction(for row: PostItRow) -> (() -> Void)? {
        guard case .sketch(let project) = row.content else { return nil }
        return {
            ProjectService.archive(project)
            try? context.save()
        }
    }

    private func remove(_ row: PostItRow) {
        switch row.content {
        case .clip(let clip): ClipService.delete(clip, context: context)
        case .sketch(let project): ProjectService.delete(project, context: context)
        }
        try? context.save()
    }

    private func statusDot(_ status: PostingItemService.DisplayStatus) -> some View {
        Circle().fill(color(for: status)).frame(width: 8, height: 8)
    }

    private func color(for status: PostingItemService.DisplayStatus) -> Color {
        switch status {
        case .notReady: return RetroTheme.secondaryText
        case .ready: return RetroTheme.accent
        case .dueToday: return RetroTheme.warning
        case .posted: return .green
        case .overdue: return .red
        }
    }
}

/// Wraps either a Clip or a Sketch Project so both can share one list/sheet — same "one sheet,
/// switched by kind" shape as `CalendarEventFormSheet`'s add/edit modes.
struct PostItRow: Identifiable {
    enum Content {
        case clip(PostingItemService.Clip)
        case sketch(PostingItemService.Project)
    }
    let content: Content

    var id: PersistentIdentifier {
        switch content {
        case .clip(let clip): return clip.persistentModelID
        case .sketch(let project): return project.persistentModelID
        }
    }
    var title: String {
        switch content {
        case .clip(let clip): return clip.title
        case .sketch(let project): return project.title
        }
    }
    var subtitle: String {
        switch content {
        case .clip: return "Clip"
        case .sketch: return "Sketch"
        }
    }
    /// Aesthetic Direction V2 (§0) category colour — matches `WorkItemService.Workspace.
    /// moduleCategory` (`.clips`/`.sketches`) exactly, so a Clip reads the same accent here as it
    /// does on the Clips board or a Home Weekly Board card.
    var category: RetroTheme.ModuleCategory {
        switch content {
        case .clip: return .clips
        case .sketch: return .sketches
        }
    }
    var confirmedPostDate: Date? {
        switch content {
        case .clip(let clip): return clip.postingItem?.confirmedPostDate
        case .sketch(let project): return project.postingItem?.confirmedPostDate
        }
    }
    var displayStatus: PostingItemService.DisplayStatus {
        switch content {
        case .clip(let clip): return PostingItemService.displayStatus(for: clip)
        case .sketch(let project): return PostingItemService.displayStatus(for: project)
        }
    }
}

/// Edit sheet for a single Post It row: suggested/confirmed post date, platform, and Mark Posted.
private struct PostItRowSheet: View {
    let row: PostItRow

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var hasConfirmedDate = false
    @State private var confirmedDate = Date.now
    @State private var platform = ""

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.headline).foregroundStyle(RetroTheme.primaryText)
                Text(row.displayStatus.rawValue)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }

            Toggle("Confirmed post date", isOn: $hasConfirmedDate)
                .onChange(of: hasConfirmedDate) { save() }
            if hasConfirmedDate {
                DatePicker("Post date", selection: $confirmedDate, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: confirmedDate) { save() }
            }
            TextField("Platform", text: $platform)
                .retroInputStyle()
                .onChange(of: platform) { savePlatform() }

            HStack {
                if row.displayStatus != .posted {
                    Button("Mark Posted") {
                        markPosted()
                        dismiss()
                    }
                    .buttonStyle(.retro)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.retroProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RetroTheme.sectionPadding + 8)
        .frame(minWidth: 360)
        .background(RetroTheme.panelBackground)
        .onAppear(perform: populate)
    }

    private func item() -> PostingItemService.PostingItem {
        switch row.content {
        case .clip(let clip): return PostingItemService.findOrCreate(for: clip, context: context)
        case .sketch(let project): return PostingItemService.findOrCreate(for: project, context: context)
        }
    }

    private func populate() {
        if let date = row.confirmedPostDate {
            hasConfirmedDate = true
            confirmedDate = date
        }
        switch row.content {
        case .clip(let clip): platform = clip.postingItem?.platform ?? ""
        case .sketch(let project): platform = project.postingItem?.platform ?? ""
        }
    }

    private func save() {
        let posting = item()
        PostingItemService.setConfirmedPostDate(posting, date: hasConfirmedDate ? confirmedDate : nil, context: context)
        try? context.save()
    }

    private func savePlatform() {
        PostingItemService.setPlatform(item(), platform: platform)
        try? context.save()
    }

    private func markPosted() {
        PostingItemService.markPosted(item(), context: context)
        try? context.save()
    }
}

#Preview {
    PostItView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
