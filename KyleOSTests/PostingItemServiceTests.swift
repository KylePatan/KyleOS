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

        ClipService.changeStatus(clip, to: .ready)
        XCTAssertEqual(PostingItemService.displayStatus(for: clip), .ready)

        ClipService.changeStatus(clip, to: .posted)
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
        ClipService.changeStatus(clip, to: .ready)
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
