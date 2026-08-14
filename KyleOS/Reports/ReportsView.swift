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
    @Environment(\.modelContext) private var context

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                rangePicker
                if let summary {
                    summaryGrid(summary)
                }
                if !breakdown.isEmpty {
                    workspaceBreakdownSection
                }
                if let plannedVsActual {
                    plannedVsActualSection(plannedVsActual)
                }
                if !estimateAccuracy.isEmpty {
                    estimateAccuracySection
                }
                if !stalledWorkItems.isEmpty {
                    stalledWorkSection
                }
                if !recentActivity.isEmpty {
                    recentActivitySection
                }
                if let standUpReport {
                    standUpReportSection(standUpReport)
                }
                if let clipsReport {
                    clipsReportSection(clipsReport)
                }
                if !sketchTransitions.isEmpty || sketchesEditingSeconds > 0 {
                    sketchesReportSection
                }
                if let postingReport {
                    postingReportSection(postingReport)
                }
                if !projectProgress.isEmpty {
                    projectProgressSection
                }
                if !readyBufferTrend.isEmpty {
                    readyBufferTrendSection
                }
            }
            .padding()
        }
        .navigationTitle("Reports")
        .onAppear(perform: reload)
        .onChange(of: rangeOption) { reload() }
        .onChange(of: customStart) { if rangeOption == .custom { reload() } }
        .onChange(of: customEnd) { if rangeOption == .custom { reload() } }
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
    }

    /// PRD §13.4: "Reports should support time by: Workspace..."
    private var workspaceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time by Workspace").font(.headline)
            ForEach(breakdown, id: \.workspace) { entry in
                HStack {
                    Text(entry.workspace.rawValue)
                    Spacer()
                    Text(TimeFormatting.shortDuration(entry.seconds))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 400, alignment: .leading)
    }

    /// PRD §13.6: "Compare planned Creative Hours with actual Creative Hours and planned session
    /// length with actual session length."
    private func plannedVsActualSection(_ comparison: ReportService.PlannedVsActual) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned vs Actual").font(.headline)
            HStack(spacing: 24) {
                stat(label: "Planned Hours", value: TimeFormatting.shortDuration(Int(comparison.plannedHours * 3600)))
                stat(label: "Actual Hours", value: TimeFormatting.shortDuration(Int(comparison.actualHours * 3600)))
                stat(label: "Avg Planned Session", value: TimeFormatting.shortDuration(Int(comparison.averagePlannedMinutes * 60)))
                stat(label: "Avg Actual Session", value: TimeFormatting.shortDuration(Int(comparison.averageActualMinutes * 60)))
            }
        }
    }

    /// PRD §13.7: "Compare default estimates with actual historical completion times." Read-only
    /// display — no button here changes any estimate, matching the PRD's "must never silently
    /// change estimates without user approval."
    private var estimateAccuracySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimate Accuracy — Completed This Range").font(.headline)
            ForEach(estimateAccuracy) { entry in
                HStack {
                    Text(entry.title)
                    Text("(\(entry.workTypeName))").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Est \(entry.estimatedMinutes)m")
                        .foregroundStyle(.secondary)
                    Text("Actual \(entry.actualMinutes)m")
                        .foregroundStyle(.secondary)
                    Text(entry.varianceMinutes >= 0 ? "+\(entry.varianceMinutes)m" : "\(entry.varianceMinutes)m")
                        .foregroundStyle(entry.varianceMinutes > 0 ? .orange : .green)
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
            Text("Not Worked On Recently (14+ days)").font(.headline)
            ForEach(stalledWorkItems) { entry in
                HStack {
                    Text(entry.title)
                    Spacer()
                    Text(entry.lastActivityAt, format: .dateTime.month().day().year())
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
    }

    /// PRD §14.19: "Important status changes and progress changes should create history records."
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity").font(.headline)
            ForEach(recentActivity) { entry in
                HStack {
                    Text(entry.subjectTitle)
                    Text(entry.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.oldValue) → \(entry.newValue)")
                        .foregroundStyle(.secondary)
                    Text(entry.occurredAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            Text("Stand Up").font(.headline)
            HStack(spacing: 24) {
                stat(label: "Creative Time", value: TimeFormatting.shortDuration(report.creativeSeconds))
                stat(label: "Joke Ideas Created", value: "\(report.jokeIdeasCreatedCount)")
                stat(label: "Moved to New", value: "\(report.jokesMovedToNewCount)")
                stat(label: "Moved to Done", value: "\(report.jokesMovedToDoneCount)")
                stat(label: "Chunks Created", value: "\(report.chunksCreatedCount)")
                stat(label: "Gigs Performed", value: "\(report.gigsPerformedCount)")
            }
            if !headlineSetProgress.isEmpty {
                Text("Headline Set Runtime vs Target").font(.subheadline)
                ForEach(headlineSetProgress) { entry in
                    HStack {
                        Text(entry.title)
                        Spacer()
                        Text("\(TimeFormatting.shortDuration(entry.currentSeconds)) / \(TimeFormatting.shortDuration(entry.targetSeconds))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            if !timeByMaterial.isEmpty {
                Text("Time by Material").font(.subheadline)
                ForEach(timeByMaterial) { entry in
                    HStack {
                        Text(entry.title)
                        Spacer()
                        Text(TimeFormatting.shortDuration(entry.seconds))
                            .foregroundStyle(.secondary)
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
            Text("Clips").font(.headline)
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !topSources.isEmpty {
                Text("Top Sources: " + topSources.map { "\($0.sourceTitle) (\($0.clipCount))" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// PRD §13.11: "Sketches written/filmed/edited/posted; Writing-to-post turnaround; Editing
    /// time; Production time; Full project lifecycle time."
    private var sketchesReportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sketches").font(.headline)
            stat(label: "Editing Time", value: TimeFormatting.shortDuration(sketchesEditingSeconds))
            if !sketchTransitions.isEmpty {
                HStack(spacing: 16) {
                    ForEach(sketchTransitions.filter { $0.count > 0 }, id: \.status) { entry in
                        Text("\(entry.status.rawValue): \(entry.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !sketchTurnaround.isEmpty {
                Text("Writing-to-Post Turnaround").font(.subheadline)
                ForEach(sketchTurnaround) { entry in
                    HStack {
                        Text(entry.title)
                        Spacer()
                        Text("\(entry.turnaroundDays)d")
                            .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Posting").font(.headline)
            HStack(spacing: 24) {
                stat(label: "Posts This Range", value: "\(report.postsCount)")
                stat(label: "Clips vs Sketches", value: "\(report.clipsPostedCount) / \(report.sketchesPostedCount)")
                stat(label: "Actual per Week", value: String(format: "%.1f", report.actualPerWeek))
                stat(label: "Target per Week", value: "\(report.targetPerWeek)")
                stat(label: "Ready & Waiting", value: "\(report.readyPiecesWaitingCount)")
                stat(label: "Missed Posts", value: "\(report.missedPlannedPostsCount)")
            }
        }
    }

    /// "Project progress" — sum of hours per Project, plus which Work Item is most recently
    /// active. All-time, not date-ranged (project time is cumulative, per PRD §4.3).
    private var projectProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Progress").font(.headline)
            ForEach(projectProgress) { entry in
                HStack {
                    Text(entry.title)
                    Spacer()
                    if let mostRecentItemTitle = entry.mostRecentItemTitle {
                        Text("Focus: \(mostRecentItemTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "%.1fh", entry.totalHours))
                        .foregroundStyle(.secondary)
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
            Text("Ready Buffer Trend").font(.headline)
            ForEach(Array(readyBufferTrend.enumerated()), id: \.offset) { _, point in
                HStack {
                    Text(point.date, format: .dateTime.month().day())
                    Spacer()
                    Text("Clips: \(point.clipsCount)")
                        .foregroundStyle(.secondary)
                    Text("Sketches: \(point.sketchesCount)")
                        .foregroundStyle(.secondary)
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
