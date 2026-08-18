import SwiftUI
import SwiftData

/// PRD §13: the Reports workspace. Covers §13.2 (Default Summary, "This Week" by default),
/// §13.4's Workspace time breakdown, §13.6 (Planned vs Actual), §13.7 (Estimate Accuracy), §13.8
/// (Active/Stalled Work), Recent Activity (§14.19's status/progress history log), §13.9 (Stand-Up
/// Reports: Creative Hours, Joke ideas created, Jokes moved to New/Done, Chunks created, Headline
/// Set runtime vs target, Gigs performed, time by material), §13.10/§13.11 (Clips/Sketch Reports,
/// including precise status-transition counts and Sketch Writing-to-Post turnaround), §13.12
/// (Posting Reports: cadence, Ready & Waiting, Missed Posts, Clips vs Sketches), Project Progress
/// (sum of hours per Project + its most-recently-active Work Item), and Ready Buffer Trends
/// (reconstructed from the HistoryEvent log) — see `ReportService`'s own doc comment for the
/// reasoning behind the last two.
struct ReportsView: View {
    /// Kyle (2026-08-18): "simplify... how clunky the information is presented" — Reports was one
    /// long scroll of 12 always-stacked panels, several of them empty most weeks. Grouped into the
    /// same tab pattern every other Home-style screen already uses (StandUpHomeView/WritingHomeView/
    /// ClipsHomeView's `RetroTabs`), by PRD section family, so a given visit only shows what's
    /// actually relevant to what the user's looking for — the date range picker stays pinned above
    /// the tabs since it filters all of them, not scrolled away with whichever tab is selected.
    private enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case work = "Work"
        case standUp = "Stand Up"
        case production = "Production"
        case posting = "Posting"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @State private var selectedTab: Tab = .overview

    @State private var rangeOption: ReportService.DateRangeOption = .thisWeek
    @State private var customStart = Date.now
    @State private var customEnd = Date.now
    @State private var summary: ReportService.Summary?
    @State private var breakdown: [(workspace: ReportService.Workspace, seconds: Int)] = []
    @State private var plannedVsActual: ReportService.PlannedVsActual?
    @State private var estimateAccuracy: [ReportService.EstimateAccuracyEntry] = []
    @State private var stalledWorkItems: [ReportService.StalledWorkItemEntry] = []
    @State private var recentActivity: [ReportService.HistoryEntry] = []
    @State private var clipTransitions: [(status: ReportService.ClipStatus, count: Int)] = []
    @State private var clipsReport: ReportService.ClipsReport?
    @State private var topSources: [(sourceTitle: String, clipCount: Int)] = []
    @State private var sketchTransitions: [(status: ReportService.SketchProductionStatus, count: Int)] = []
    @State private var sketchesEditingSeconds = 0
    @State private var sketchTurnaround: [ReportService.SketchTurnaroundEntry] = []
    @State private var postingReport: ReportService.PostingReport?
    @State private var standUpReport: ReportService.StandUpReport?
    @State private var headlineSetProgress: [ReportService.HeadlineSetProgressEntry] = []
    @State private var timeByMaterial: [ReportService.MaterialTimeEntry] = []
    @State private var projectProgress: [ReportService.ProjectProgressEntry] = []
    @State private var readyBufferTrend: [ReportService.ReadyBufferTrendPoint] = []

    private var interval: DateInterval {
        ReportService.interval(for: rangeOption, customStart: customStart, customEnd: customEnd)
    }

    /// Whether a tab has anything to show right now — used to hide empty tabs from the strip
    /// entirely rather than let the user land on a blank pane (most weeks have no Sketches
    /// activity, for instance).
    private func hasContent(_ tab: Tab) -> Bool {
        switch tab {
        case .overview: return summary != nil || !breakdown.isEmpty || plannedVsActual != nil
        case .work: return !estimateAccuracy.isEmpty || !stalledWorkItems.isEmpty || !recentActivity.isEmpty || !projectProgress.isEmpty
        case .standUp: return standUpReport != nil
        case .production: return clipsReport != nil || !sketchTransitions.isEmpty || sketchesEditingSeconds > 0 || !readyBufferTrend.isEmpty
        case .posting: return postingReport != nil
        }
    }

    private var visibleTabs: [Tab] {
        let withContent = Tab.allCases.filter(hasContent)
        return withContent.isEmpty ? [.overview] : withContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rangePicker
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.top, RetroTheme.controlSpacing)
            RetroTabs(tabs: visibleTabs.map { ($0, $0.rawValue) }, selection: $selectedTab)
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.top, RetroTheme.controlSpacing)

            ScrollView {
                VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                    tabContent
                }
                .padding(RetroTheme.sectionPadding)
            }
        }
        .background(RetroTheme.background)
        .navigationTitle("Reports")
        .onAppear(perform: reload)
        .onChange(of: rangeOption) { reload() }
        .onChange(of: customStart) { if rangeOption == .custom { reload() } }
        .onChange(of: customEnd) { if rangeOption == .custom { reload() } }
        .onChange(of: visibleTabs) { if !visibleTabs.contains(selectedTab) { selectedTab = visibleTabs[0] } }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            if let summary {
                RetroPanel("Summary") { summaryGrid(summary) }
            }
            if !breakdown.isEmpty {
                RetroPanel("Time by Workspace") { workspaceBreakdownSection }
            }
            if let plannedVsActual {
                RetroPanel("Planned vs Actual") { plannedVsActualSection(plannedVsActual) }
            }
            if !hasContent(.overview) {
                emptyTabMessage
            }
        case .work:
            if !estimateAccuracy.isEmpty {
                RetroPanel("Estimate Accuracy — Completed This Range") { estimateAccuracySection }
            }
            if !stalledWorkItems.isEmpty {
                RetroPanel("Not Worked On Recently (14+ days)") { stalledWorkSection }
            }
            if !recentActivity.isEmpty {
                RetroPanel("Recent Activity") { recentActivitySection }
            }
            if !projectProgress.isEmpty {
                RetroPanel("Project Progress") { projectProgressSection }
            }
            if !hasContent(.work) {
                emptyTabMessage
            }
        case .standUp:
            if let standUpReport {
                RetroPanel("Stand Up") { standUpReportSection(standUpReport) }
            } else {
                emptyTabMessage
            }
        case .production:
            if let clipsReport {
                RetroPanel("Clips") { clipsReportSection(clipsReport) }
            }
            if !sketchTransitions.isEmpty || sketchesEditingSeconds > 0 {
                RetroPanel("Sketches") { sketchesReportSection }
            }
            if !readyBufferTrend.isEmpty {
                RetroPanel("Ready Buffer Trend") { readyBufferTrendSection }
            }
            if !hasContent(.production) {
                emptyTabMessage
            }
        case .posting:
            if let postingReport {
                RetroPanel("Posting") { postingReportSection(postingReport) }
            } else {
                emptyTabMessage
            }
        }
    }

    private var emptyTabMessage: some View {
        Text("Nothing to report here for this range yet.")
            .foregroundStyle(RetroTheme.secondaryText)
    }

    private var rangePicker: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                Picker("Date range", selection: $rangeOption) {
                    ForEach(ReportService.DateRangeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 500)

                if rangeOption == .custom {
                    HStack {
                        DatePicker("From", selection: $customStart, displayedComponents: .date)
                        DatePicker("To", selection: $customEnd, displayedComponents: .date)
                    }
                }
            }
        }
    }

    /// PRD §13.2: "Total Creative Time, Sessions, Projects Worked On, Completed Items, Content
    /// Posted."
    private func summaryGrid(_ summary: ReportService.Summary) -> some View {
        HStack(alignment: .top, spacing: 24) {
            stat(label: "Total Creative Time", value: TimeFormatting.shortDuration(summary.totalCreativeSeconds))
            stat(label: "Sessions", value: "\(summary.sessionCount)")
            stat(label: "Projects Worked On", value: "\(summary.projectsWorkedOnCount)")
            stat(label: "Completed Items", value: "\(summary.completedItemsCount)")
            stat(label: "Content Posted", value: "\(summary.contentPostedCount)")
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(RetroTheme.secondaryText)
            Text(value).font(.title3.bold()).foregroundStyle(RetroTheme.primaryText)
        }
    }

    /// PRD §13.4: "Reports should support time by: Workspace..."
    private var workspaceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(breakdown, id: \.workspace) { entry in
                HStack {
                    Text(entry.workspace.rawValue).foregroundStyle(RetroTheme.primaryText)
                    Spacer()
                    Text(TimeFormatting.shortDuration(entry.seconds))
                        .foregroundStyle(RetroTheme.secondaryText)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 400, alignment: .leading)
    }

    /// PRD §13.6: "Compare planned Creative Hours with actual Creative Hours and planned session
    /// length with actual session length."
    private func plannedVsActualSection(_ comparison: ReportService.PlannedVsActual) -> some View {
        HStack(spacing: 24) {
            stat(label: "Planned Hours", value: TimeFormatting.shortDuration(Int(comparison.plannedHours * 3600)))
            stat(label: "Actual Hours", value: TimeFormatting.shortDuration(Int(comparison.actualHours * 3600)))
            stat(label: "Avg Planned Session", value: TimeFormatting.shortDuration(Int(comparison.averagePlannedMinutes * 60)))
            stat(label: "Avg Actual Session", value: TimeFormatting.shortDuration(Int(comparison.averageActualMinutes * 60)))
        }
    }

    /// PRD §13.7: "Compare default estimates with actual historical completion times." Read-only
    /// display — no button here changes any estimate, matching the PRD's "must never silently
    /// change estimates without user approval."
    private var estimateAccuracySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(estimateAccuracy) { entry in
                HStack {
                    Text(entry.title).foregroundStyle(RetroTheme.primaryText)
                    Text("(\(entry.workTypeName))").font(.caption).foregroundStyle(RetroTheme.secondaryText)
                    Spacer()
                    Text("Est \(entry.estimatedMinutes)m")
                        .foregroundStyle(RetroTheme.secondaryText)
                    Text("Actual \(entry.actualMinutes)m")
                        .foregroundStyle(RetroTheme.secondaryText)
                    Text(entry.varianceMinutes >= 0 ? "+\(entry.varianceMinutes)m" : "\(entry.varianceMinutes)m")
                        .foregroundStyle(entry.varianceMinutes > 0 ? RetroTheme.warning : Color.green)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    /// PRD §13.8: "Optionally surface projects not worked on recently. This is informational and
    /// should not treat inactivity as failure" — plain list, no visual alarm styling.
    private var stalledWorkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(stalledWorkItems) { entry in
                HStack {
                    Text(entry.title).foregroundStyle(RetroTheme.primaryText)
                    Spacer()
                    Text(entry.lastActivityAt, format: .dateTime.month().day().year())
                        .foregroundStyle(RetroTheme.secondaryText)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
    }

    /// PRD §14.19: "Important status changes and progress changes should create history records."
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(recentActivity) { entry in
                HStack {
                    Text(entry.subjectTitle).foregroundStyle(RetroTheme.primaryText)
                    Text(entry.kind.rawValue).font(.caption).foregroundStyle(RetroTheme.secondaryText)
                    Spacer()
                    Text("\(entry.oldValue) → \(entry.newValue)")
                        .foregroundStyle(RetroTheme.secondaryText)
                    Text(entry.occurredAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    /// PRD §13.9: "Stand-Up Creative Hours; Joke ideas created; Jokes moved to New/Done; Chunks
    /// created; Headline Set runtime vs target; Gigs performed; Time spent on individual material."
    private func standUpReportSection(_ report: ReportService.StandUpReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 24) {
                stat(label: "Creative Time", value: TimeFormatting.shortDuration(report.creativeSeconds))
                stat(label: "Joke Ideas Created", value: "\(report.jokeIdeasCreatedCount)")
                stat(label: "Moved to New", value: "\(report.jokesMovedToNewCount)")
                stat(label: "Moved to Done", value: "\(report.jokesMovedToDoneCount)")
                stat(label: "Chunks Created", value: "\(report.chunksCreatedCount)")
                stat(label: "Gigs Performed", value: "\(report.gigsPerformedCount)")
            }
            if !headlineSetProgress.isEmpty {
                Text("Headline Set Runtime vs Target").font(.subheadline).foregroundStyle(RetroTheme.primaryText)
                ForEach(headlineSetProgress) { entry in
                    HStack {
                        Text(entry.title).foregroundStyle(RetroTheme.primaryText)
                        Spacer()
                        Text("\(TimeFormatting.shortDuration(entry.currentSeconds)) / \(TimeFormatting.shortDuration(entry.targetSeconds))")
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                    .font(.callout)
                }
            }
            if !timeByMaterial.isEmpty {
                Text("Time by Material").font(.subheadline).foregroundStyle(RetroTheme.primaryText)
                ForEach(timeByMaterial) { entry in
                    HStack {
                        Text(entry.title).foregroundStyle(RetroTheme.primaryText)
                        Spacer()
                        Text(TimeFormatting.shortDuration(entry.seconds))
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                    .font(.callout)
                }
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    /// PRD §13.10: "Clips identified, edited, ready, posted; Editing/subtitle time; Average
    /// production time per clip; Ready buffer; Source recordings that generated the most usable
    /// clips."
    private func clipsReportSection(_ report: ReportService.ClipsReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 24) {
                stat(label: "Editing Time", value: TimeFormatting.shortDuration(report.editingSeconds))
                stat(label: "Avg per Clip", value: TimeFormatting.shortDuration(report.averageProductionSeconds))
                stat(label: "Ready Buffer", value: "\(report.readyBufferCount)")
                stat(label: "Scheduled", value: "\(report.scheduledCount)")
                stat(label: "Backlog", value: "\(report.productionBacklogCount)")
            }
            if !clipTransitions.isEmpty {
                HStack(spacing: 16) {
                    ForEach(clipTransitions.filter { $0.count > 0 }, id: \.status) { entry in
                        Text("\(entry.status.rawValue): \(entry.count)")
                            .font(.caption)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                }
            }
            if !topSources.isEmpty {
                Text("Top Sources: " + topSources.map { "\($0.sourceTitle) (\($0.clipCount))" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
        }
    }

    /// PRD §13.11: "Sketches written/filmed/edited/posted; Writing-to-post turnaround; Editing
    /// time; Production time; Full project lifecycle time."
    private var sketchesReportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            stat(label: "Editing Time", value: TimeFormatting.shortDuration(sketchesEditingSeconds))
            if !sketchTransitions.isEmpty {
                HStack(spacing: 16) {
                    ForEach(sketchTransitions.filter { $0.count > 0 }, id: \.status) { entry in
                        Text("\(entry.status.rawValue): \(entry.count)")
                            .font(.caption)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                }
            }
            if !sketchTurnaround.isEmpty {
                Text("Writing-to-Post Turnaround").font(.subheadline).foregroundStyle(RetroTheme.primaryText)
                ForEach(sketchTurnaround) { entry in
                    HStack {
                        Text(entry.title).foregroundStyle(RetroTheme.primaryText)
                        Spacer()
                        Text("\(entry.turnaroundDays)d")
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                    .font(.callout)
                }
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    /// PRD §13.12: "Posts per week/month; Target cadence vs actual cadence; Ready pieces waiting;
    /// Missed planned posts; Clips vs Sketches posted."
    private func postingReportSection(_ report: ReportService.PostingReport) -> some View {
        HStack(spacing: 24) {
            stat(label: "Posts This Range", value: "\(report.postsCount)")
            stat(label: "Clips vs Sketches", value: "\(report.clipsPostedCount) / \(report.sketchesPostedCount)")
            stat(label: "Actual per Week", value: String(format: "%.1f", report.actualPerWeek))
            stat(label: "Target per Week", value: "\(report.targetPerWeek)")
            stat(label: "Ready & Waiting", value: "\(report.readyPiecesWaitingCount)")
            stat(label: "Missed Posts", value: "\(report.missedPlannedPostsCount)")
        }
    }

    /// "Project progress" — sum of hours per Project, plus which Work Item is most recently
    /// active. All-time, not date-ranged (project time is cumulative, per PRD §4.3).
    private var projectProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(projectProgress) { entry in
                HStack {
                    Text(entry.title).foregroundStyle(RetroTheme.primaryText)
                    Spacer()
                    if let mostRecentItemTitle = entry.mostRecentItemTitle {
                        Text("Focus: \(mostRecentItemTitle)")
                            .font(.caption)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                    Text(String(format: "%.1fh", entry.totalHours))
                        .foregroundStyle(RetroTheme.secondaryText)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    /// "Ready buffer trends" — the Ready-buffer Clip/Sketch count as of the end of each day in
    /// the selected range, reconstructed from history rather than a live snapshot.
    private var readyBufferTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(readyBufferTrend.enumerated()), id: \.offset) { _, point in
                HStack {
                    Text(point.date, format: .dateTime.month().day()).foregroundStyle(RetroTheme.primaryText)
                    Spacer()
                    Text("Clips: \(point.clipsCount)")
                        .foregroundStyle(RetroTheme.secondaryText)
                    Text("Sketches: \(point.sketchesCount)")
                        .foregroundStyle(RetroTheme.secondaryText)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
    }

    private func reload() {
        let currentInterval = interval
        summary = try? ReportService.summary(in: currentInterval, context: context)
        breakdown = (try? ReportService.workspaceBreakdown(in: currentInterval, context: context)) ?? []
        plannedVsActual = try? ReportService.plannedVsActual(in: currentInterval, context: context)
        estimateAccuracy = (try? ReportService.estimateAccuracy(in: currentInterval, context: context)) ?? []
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        stalledWorkItems = (try? ReportService.stalledWorkItems(notWorkedOnSince: cutoff, context: context)) ?? []
        recentActivity = (try? ReportService.recentActivity(in: currentInterval, context: context)) ?? []
        clipTransitions = (try? ReportService.clipStatusTransitions(in: currentInterval, context: context)) ?? []
        clipsReport = try? ReportService.clipsReport(in: currentInterval, context: context)
        topSources = ReportService.topSourcesByClipCount(context: context)
        sketchTransitions = (try? ReportService.sketchStatusTransitions(in: currentInterval, context: context)) ?? []
        sketchesEditingSeconds = (try? ReportService.sketchesEditingSeconds(in: currentInterval, context: context)) ?? 0
        sketchTurnaround = (try? ReportService.sketchTurnaround(in: currentInterval, context: context)) ?? []
        postingReport = try? ReportService.postingReport(in: currentInterval, context: context)
        standUpReport = try? ReportService.standUpReport(in: currentInterval, context: context)
        headlineSetProgress = ReportService.headlineSetProgress(context: context)
        timeByMaterial = (try? ReportService.timeByMaterial(in: currentInterval, context: context)) ?? []
        projectProgress = (try? ReportService.projectProgress(context: context)) ?? []
        readyBufferTrend = (try? ReportService.readyBufferTrend(in: currentInterval, context: context)) ?? []
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(PersistenceController.makeInMemoryContainer())
}
