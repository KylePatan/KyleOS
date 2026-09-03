import SwiftUI
import SwiftData

/// Kyle (2026-08-27): "There needs to be another thing we can put in for 'HOME'... SUBMISSION...
/// We should also add a section for submissions. Here we will have things like festivals we need
/// to submit for - have due dates... and also have sections for (SUBMISSION COMING UP) and
/// (SUBMISSION ENTERED)." Two columns, same board shape as `SketchBoardView`'s own Writing/status
/// columns — just two statuses here (`SubmissionService.SubmissionStatus`), not five, so a
/// straightforward Coming Up / Entered split rather than a `ForEach(allCases)`.
struct SubmissionsBoardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator
    @Query private var allSubmissions: [SubmissionService.Submission]
    @State private var isPresentingNewSubmission = false

    private var comingUp: [SubmissionService.Submission] {
        allSubmissions
            .filter { $0.status == .comingUp }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var entered: [SubmissionService.Submission] {
        allSubmissions
            .filter { $0.status == .entered }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allSubmissions.isEmpty {
                    Text("No Submissions yet. Add a festival or production company to start tracking deadlines.")
                        .foregroundStyle(RetroTheme.secondaryText)
                        .padding(RetroTheme.sectionPadding)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: RetroTheme.sectionSpacing) {
                            column("Submission Coming Up", items: comingUp)
                            column("Submission Entered", items: entered)
                        }
                        .padding(RetroTheme.sectionPadding)
                    }
                }
            }
            .navigationTitle("Submissions")
            .background(RetroTheme.background)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewSubmission = true
                    } label: {
                        Label("Add Submission", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewSubmission) {
                NewSubmissionSheet()
            }
        }
        .task(id: navigator.pendingTarget) { consumePendingTarget() }
    }

    /// Nothing to actually navigate *to* yet (no detail screen — cards edit inline, same as
    /// `SketchBoardView`'s WritingSketchCard) — just clears a stale target so switching here
    /// manually afterward doesn't replay it, same as every other module's own consume hook.
    private func consumePendingTarget() {
        guard case .submission = navigator.pendingTarget else { return }
        navigator.pendingTarget = nil
    }

    // Kyle (2026-08-27): "when there are many items anywhere, it has to be able to scroll to see
    // everything." A column with many submissions used to just keep growing past the window's
    // bottom edge with no way to reach the rest.
    private func column(_ title: String, items: [SubmissionService.Submission]) -> some View {
        RetroPanel(title, accentCategory: .submissions) {
            Group {
                if items.isEmpty {
                    Text("No submissions here.")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(items) { submission in
                                SubmissionCard(submission: submission)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct SubmissionCard: View {
    let submission: SubmissionService.Submission
    @Environment(\.modelContext) private var context

    private var reminderDate: Date? {
        submission.status == .entered ? SubmissionService.reminderDate(for: submission) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(submission.title).font(.callout.bold()).foregroundStyle(RetroTheme.primaryText)

            DeadlineControl(
                label: "Submission",
                dueAt: submission.dueAt,
                isHard: true,
                onSet: { date, isHard in
                    SubmissionService.setDueDate(submission, to: date, isHard: isHard, context: context)
                    try? context.save()
                },
                onRemove: {
                    SubmissionService.removeDueDate(submission, context: context)
                    try? context.save()
                }
            )

            if let reminderDate {
                Text("Reminder: \(reminderDate.formatted(date: .abbreviated, time: .omitted)) — may be open again")
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.secondaryText)
            }

            switch submission.status {
            case .comingUp:
                Button("Mark Entered") {
                    SubmissionService.markEntered(submission, context: context)
                    try? context.save()
                }
                .buttonStyle(.retroCompact)
            case .entered:
                Button("Reopen for Next Cycle") {
                    SubmissionService.reopenForNextCycle(submission, context: context)
                    try? context.save()
                }
                .buttonStyle(.retroCompact)
            }
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        .archiveDeleteContextMenu(
            onDelete: {
                SubmissionService.delete(submission, context: context)
                try? context.save()
            }
        )
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    _ = SubmissionService.createSubmission(title: "This Hour Has 22 Minutes", dueAt: .now.addingTimeInterval(86400 * 14), context: context)
    let entered = SubmissionService.createSubmission(title: "Just For Laughs", dueAt: .now.addingTimeInterval(-86400 * 30), context: context)
    SubmissionService.markEntered(entered, context: context)
    return NavigationStack {
        SubmissionsBoardView()
    }
    .modelContainer(container)
    .environment(AppNavigationController())
}
