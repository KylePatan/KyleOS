import SwiftUI
import SwiftData

/// PRD §13: the Reports workspace. First increment covers §13.2 (Default Summary, "This Week" by
/// default) and §13.4's Workspace time breakdown — see `ReportService`'s own doc comment for what
/// depends on a Status/Progress History model that doesn't exist yet and is deliberately deferred.
struct ReportsView: View {
    @Environment(\.modelContext) private var context

    @State private var rangeOption: ReportService.DateRangeOption = .thisWeek
    @State private var customStart = Date.now
    @State private var customEnd = Date.now
    @State private var summary: ReportService.Summary?
    @State private var breakdown: [(workspace: ReportService.Workspace, seconds: Int)] = []

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

    private func reload() {
        let currentInterval = interval
        summary = try? ReportService.summary(in: currentInterval, context: context)
        breakdown = (try? ReportService.workspaceBreakdown(in: currentInterval, context: context)) ?? []
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(PersistenceController.makeInMemoryContainer())
}
