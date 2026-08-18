import XCTest
import SwiftData
@testable import KyleOS

final class PostingItemServiceTests: XCTestCase {

    // MARK: - displayStatus (pure function)

    func testDisplayStatusNotReadyWhenContentNotReady() {
        let status = PostingItemService.displayStatus(isReady: false, isPosted: false, confirmedPostDate: nil)
        XCTAssertEqual(status, .notReady)
    }

    func testDisplayStatusReadyWithNoConfirmedDate() {
        let status = PostingItemService.displayStatus(isReady: true, isPosted: false, confirmedPostDate: nil)
        XCTAssertEqual(status, .ready)
    }

    func testDisplayStatusDueTodayWhenConfirmedDateIsToday() {
        let status = PostingItemService.displayStatus(isReady: true, isPosted: false, confirmedPostDate: .now, now: .now)
        XCTAssertEqual(status, .dueToday)
    }

    func testDisplayStatusOverdueWhenConfirmedDateHasPassed() {
        let now = Date()
        let status = PostingItemService.displayStatus(
            isReady: true, isPosted: false, confirmedPostDate: Date(timeIntervalSinceNow: -86400 * 3), now: now
        )
        XCTAssertEqual(status, .overdue)
    }

    func testDisplayStatusReadyWhenConfirmedDateIsInTheFuture() {
        let now = Date()
        let status = PostingItemService.displayStatus(
            isReady: true, isPosted: false, confirmedPostDate: Date(timeIntervalSinceNow: 86400 * 3), now: now
        )
        XCTAssertEqual(status, .ready)
    }

    func testDisplayStatusPostedTakesPriorityOverEverything() {
        let status = PostingItemService.displayStatus(
            isReady: true, isPosted: true, confirmedPostDate: Date(timeIntervalSinceNow: -86400 * 30)
        )
        XCTAssertEqual(status, .posted)
    }

    // MARK: - Clip integration

    func testFindOrCreateForClipCreatesOneLinkedToTheClip() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let item = PostingItemService.findOrCreate(for: clip, context: context)
        try context.save()

        XCTAssertEqual(clip.postingItem?.id, item.id)
    }

    func testFindOrCreateForClipReusesExistingOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let first = PostingItemService.findOrCreate(for: clip, context: context)
        try context.save()
        let second = PostingItemService.findOrCreate(for: clip, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testDisplayStatusForClipReflectsClipStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        XCTAssertEqual(PostingItemService.displayStatus(for: clip), .notReady, "A freshly created Clip starts To Isolate, not Ready")

        ClipService.changeStatus(clip, to: .ready, context: context)
        XCTAssertEqual(PostingItemService.displayStatus(for: clip), .ready)

        ClipService.changeStatus(clip, to: .posted, context: context)
        XCTAssertEqual(PostingItemService.displayStatus(for: clip), .posted)
    }

    func testSetConfirmedPostDateSyncsBackToClipPostDate() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        let date = Date(timeIntervalSinceNow: 86400 * 5)

        PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        try context.save()

        let confirmedDate = try XCTUnwrap(item.confirmedPostDate)
        XCTAssertEqual(confirmedDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
        let syncedClipDate = try XCTUnwrap(clip.postDate)
        XCTAssertEqual(syncedClipDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1, "Existing Ready Queue UI reads Clip.postDate directly and must stay in sync")
    }

    func testMarkPostedAdvancesClipStatusAndRecordsActualDate() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        ClipService.changeStatus(clip, to: .ready, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)

        let now = Date()
        PostingItemService.markPosted(item, context: context, now: now)
        try context.save()

        XCTAssertEqual(clip.status, .posted)
        let actualPostedDate = try XCTUnwrap(item.actualPostedDate)
        XCTAssertEqual(actualPostedDate.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - Sketch integration

    func testFindOrCreateForSketchProjectCreatesOneLinkedToTheProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        let item = PostingItemService.findOrCreate(for: project, context: context)
        try context.save()

        XCTAssertEqual(project.postingItem?.id, item.id)
    }

    func testDisplayStatusForSketchReflectsProductionStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        XCTAssertEqual(PostingItemService.displayStatus(for: project), .notReady)

        SketchProductionService.changeStatus(for: project, to: .ready, context: context)
        XCTAssertEqual(PostingItemService.displayStatus(for: project), .ready)

        SketchProductionService.changeStatus(for: project, to: .posted, context: context)
        XCTAssertEqual(PostingItemService.displayStatus(for: project), .posted)
    }

    func testMarkPostedAdvancesSketchStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        SketchProductionService.changeStatus(for: project, to: .ready, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: project, context: context)

        PostingItemService.markPosted(item, context: context)
        try context.save()

        XCTAssertEqual(SketchProductionService.status(for: project), .posted)
        XCTAssertNotNil(item.actualPostedDate)
    }

    // MARK: - Calendar/To-Do sync (2026-08-17)

    func testSetConfirmedPostDateCreatesALockedPostDateCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        let date = Date(timeIntervalSinceNow: 86400 * 5)

        PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        try context.save()

        let events = try context.fetch(FetchDescriptor<CalendarEventService.CalendarEvent>())
        let event = try XCTUnwrap(events.first { $0.eventType == .postDate })
        XCTAssertEqual(event.startAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
        XCTAssertTrue(event.isLocked, "A confirmed post date is 'static and do not change' from the moment it's set")
        XCTAssertTrue(event.isHardCommitment)
    }

    func testClearingAConfirmedPostDateRemovesItsCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        PostingItemService.setConfirmedPostDate(item, date: Date(timeIntervalSinceNow: 86400 * 5), context: context)
        try context.save()

        PostingItemService.setConfirmedPostDate(item, date: nil, context: context)
        try context.save()

        let events = try context.fetch(FetchDescriptor<CalendarEventService.CalendarEvent>())
        XCTAssertFalse(events.contains { $0.eventType == .postDate })
    }

    func testSettingAConfirmedPostDateTwiceUpdatesInPlaceRatherThanDuplicating() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)

        PostingItemService.setConfirmedPostDate(item, date: Date(timeIntervalSinceNow: 86400 * 5), context: context)
        try context.save()
        let newDate = Date(timeIntervalSinceNow: 86400 * 9)
        PostingItemService.setConfirmedPostDate(item, date: newDate, context: context)
        try context.save()

        let events = try context.fetch(FetchDescriptor<CalendarEventService.CalendarEvent>())
        let postDateEvents = events.filter { $0.eventType == .postDate }
        XCTAssertEqual(postDateEvents.count, 1)
        XCTAssertEqual(postDateEvents[0].startAt.timeIntervalSince1970, newDate.timeIntervalSince1970, accuracy: 1)
    }

    func testConfirmedPostDateWorkItemRanksIntoSchedulingService() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        let date = Date(timeIntervalSinceNow: 86400)

        PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        try context.save()

        let allWorkItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        let postingWorkItem = try XCTUnwrap(allWorkItems.first { $0.workTypeName == "Clip Posting" })
        let postingDeadline = try XCTUnwrap(postingWorkItem.deadline)
        XCTAssertEqual(postingDeadline.dueAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
        let ranked = SchedulingService.rankedItems(from: allWorkItems)
        XCTAssertTrue(ranked.contains { $0.workItem.id == postingWorkItem.id }, "A confirmed post date must show up in the Weekly Board's To Do, same as any other deadline")
    }

    func testAllConfirmedPostDatesExcludesPostedContent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let readyClip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        ClipService.changeStatus(readyClip, to: .ready, context: context)
        let postedClip = ClipService.createClip(title: "Old Bit", in: source, context: context)
        ClipService.changeStatus(postedClip, to: .posted, context: context)
        try context.save()

        let readyItem = PostingItemService.findOrCreate(for: readyClip, context: context)
        PostingItemService.setConfirmedPostDate(readyItem, date: Date(timeIntervalSinceNow: 86400), context: context)
        let postedItem = PostingItemService.findOrCreate(for: postedClip, context: context)
        PostingItemService.setConfirmedPostDate(postedItem, date: Date(timeIntervalSinceNow: -86400), context: context)
        try context.save()

        let dates = PostingItemService.allConfirmedPostDates(in: context)
        XCTAssertEqual(dates.count, 1, "A Posted clip's old confirmed date must not count toward the clustering-avoidance pool")
    }

    func testRecommendedPostDateReturnsNilWithoutAPostingGoal() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updatePostsPerWeekTarget(settings, to: 0)
        try context.save()

        XCTAssertNil(PostingItemService.recommendedPostDate(in: context))
    }

    func testRecommendedPostDateReturnsADateWithAPostingGoalSet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updatePostsPerWeekTarget(settings, to: 3)
        try context.save()

        XCTAssertNotNil(PostingItemService.recommendedPostDate(in: context))
    }

    // MARK: - Deletion / cascade

    func testDeletingAClipCascadeDeletesItsPostingItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        let itemID = item.id
        try context.save()

        ClipService.delete(clip, context: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PostingItemService.PostingItem>())
        XCTAssertFalse(remaining.contains { $0.id == itemID }, "Deleting a Clip must cascade-delete its Posting Item")
    }
}
