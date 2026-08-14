import Foundation
import SwiftData

/// Reusable domain actions for Work Sessions (PRD §14.8), kept out of views per CLAUDE.md §4.
///
/// This only supports creating a completed session record — there is deliberately no update/edit
/// function, matching the PRD: "Historical completed sessions must never be rewritten by future
/// rescheduling." The shared timer service (build brief step 12) will call
/// `logCompletedSession` once a live start/pause/resume/stop flow finishes; this step only adds
/// the data model and the persistence primitive it will use.
enum WorkSessionService {
    typealias WorkSession = KyleOSSchemaV30.WorkSession
    typealias WorkSessionEntryType = KyleOSSchemaV30.WorkSessionEntryType
    typealias WorkItem = KyleOSSchemaV30.WorkItem

    @discardableResult
    static func logCompletedSession(
        for workItem: WorkItem,
        startAt: Date,
        endAt: Date,
        activeDurationSeconds: Int,
        pausedDurationSeconds: Int = 0,
        plannedDurationMinutes: Int? = nil,
        progressBefore: Int,
        progressAfter: Int,
        note: String = "",
        entryType: WorkSessionEntryType,
        context: ModelContext
    ) -> WorkSession {
        let session = WorkSession(
            workItem: workItem,
            startAt: startAt,
            endAt: endAt,
            activeDurationSeconds: activeDurationSeconds,
            pausedDurationSeconds: pausedDurationSeconds,
            plannedDurationMinutes: plannedDurationMinutes,
            progressBefore: progressBefore,
            progressAfter: progressAfter,
            note: note,
            entryType: entryType
        )
        context.insert(session)
        return session
    }

    static func sessions(for workItem: WorkItem, in context: ModelContext) throws -> [WorkSession] {
        let workItemID = workItem.id
        let descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate { $0.workItem?.id == workItemID },
            sortBy: [SortDescriptor(\.startAt)]
        )
        return try context.fetch(descriptor)
    }
}
