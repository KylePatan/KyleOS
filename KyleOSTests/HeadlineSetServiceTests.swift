import XCTest
import SwiftData
@testable import KyleOS

final class HeadlineSetServiceTests: XCTestCase {

    func testCreateHeadlineSetDefaultsTargetToSixtyMinutes() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        try context.save()

        XCTAssertEqual(set.targetDurationMinutes, 60)
    }

    func testRenameUpdateNotesAndUpdateTargetDurationPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Draft Set", context: context)
        try context.save()

        HeadlineSetService.rename(set, to: "Fall Tour Set")
        HeadlineSetService.updateNotes(set, notes: "Open strong, close on the travel bit.")
        HeadlineSetService.updateTargetDuration(set, minutes: 45)
        try context.save()

        XCTAssertEqual(set.title, "Fall Tour Set")
        XCTAssertEqual(set.notes, "Open strong, close on the travel bit.")
        XCTAssertEqual(set.targetDurationMinutes, 45)
    }

    func testUpdateTargetDurationNeverGoesNegative() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Set", context: context)
        try context.save()

        HeadlineSetService.updateTargetDuration(set, minutes: -10)

        XCTAssertEqual(set.targetDurationMinutes, 0)
    }

    func testAddChunkAppendsWithAscendingOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        let chunkOne = ChunkService.createChunk(title: "Travel Bit", context: context)
        let chunkTwo = ChunkService.createChunk(title: "Tech Bit", context: context)
        try context.save()

        HeadlineSetService.addChunk(chunkOne, to: set)
        HeadlineSetService.addChunk(chunkTwo, to: set)
        try context.save()

        XCTAssertEqual(HeadlineSetService.chunks(in: set).map(\.id), [chunkOne.id, chunkTwo.id])
        XCTAssertEqual(chunkOne.displayOrderInHeadlineSet, 0)
        XCTAssertEqual(chunkTwo.displayOrderInHeadlineSet, 1)
    }

    func testTotalRuntimeRollsUpFromMemberChunksTreatingNilAsZero() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        let chunkOne = ChunkService.createChunk(title: "Travel Bit", context: context)
        chunkOne.runtimeSeconds = 300
        let chunkTwo = ChunkService.createChunk(title: "Tech Bit", context: context)
        chunkTwo.runtimeSeconds = nil
        let chunkThree = ChunkService.createChunk(title: "Closer", context: context)
        chunkThree.runtimeSeconds = 180
        try context.save()
        HeadlineSetService.addChunk(chunkOne, to: set)
        HeadlineSetService.addChunk(chunkTwo, to: set)
        HeadlineSetService.addChunk(chunkThree, to: set)
        try context.save()

        XCTAssertEqual(HeadlineSetService.totalRuntimeSeconds(for: set), 480)
    }

    func testTargetDurationSecondsConvertsMinutesCorrectly() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Set", targetDurationMinutes: 45, context: context)
        try context.save()

        XCTAssertEqual(HeadlineSetService.targetDurationSeconds(for: set), 2700)
    }

    func testRemoveChunkClearsRelationshipWithoutDeletingTheChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        let chunkOne = ChunkService.createChunk(title: "Travel Bit", context: context)
        let chunkTwo = ChunkService.createChunk(title: "Tech Bit", context: context)
        try context.save()
        HeadlineSetService.addChunk(chunkOne, to: set)
        HeadlineSetService.addChunk(chunkTwo, to: set)
        try context.save()

        HeadlineSetService.removeChunk(chunkOne, from: set)
        try context.save()

        XCTAssertNil(chunkOne.headlineSet)
        XCTAssertNotNil(try context.fetch(FetchDescriptor<ChunkService.Chunk>()).first { $0.id == chunkOne.id })
        XCTAssertEqual(HeadlineSetService.chunks(in: set).map(\.id), [chunkTwo.id])
        XCTAssertEqual(chunkTwo.displayOrderInHeadlineSet, 0)
    }

    func testReorderChunksMovingLastToFirstRenumbersTheSet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        let chunkOne = ChunkService.createChunk(title: "One", context: context)
        let chunkTwo = ChunkService.createChunk(title: "Two", context: context)
        let chunkThree = ChunkService.createChunk(title: "Three", context: context)
        try context.save()
        HeadlineSetService.addChunk(chunkOne, to: set)
        HeadlineSetService.addChunk(chunkTwo, to: set)
        HeadlineSetService.addChunk(chunkThree, to: set)
        try context.save()

        HeadlineSetService.reorderChunks(in: set, movingFromOffsets: IndexSet(integer: 2), toOffset: 0)
        try context.save()

        XCTAssertEqual(HeadlineSetService.chunks(in: set).map(\.id), [chunkThree.id, chunkOne.id, chunkTwo.id])
    }

    func testLooseChunksExcludesChunksAlreadyInAHeadlineSet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        let assigned = ChunkService.createChunk(title: "Travel Bit", context: context)
        let loose = ChunkService.createChunk(title: "Tech Bit", context: context)
        try context.save()
        HeadlineSetService.addChunk(assigned, to: set)
        try context.save()

        XCTAssertEqual(HeadlineSetService.looseChunks(in: context).map(\.id), [loose.id])
    }

    func testDeletingAHeadlineSetDoesNotDeleteItsMemberChunks() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        try context.save()
        HeadlineSetService.addChunk(chunk, to: set)
        try context.save()

        HeadlineSetService.delete(set, context: context)
        try context.save()

        let survivingChunk = try context.fetch(FetchDescriptor<ChunkService.Chunk>()).first { $0.id == chunk.id }
        XCTAssertNotNil(survivingChunk, "PRD §7.7: deleting a Headline Set must not delete its Chunks")
        XCTAssertNil(survivingChunk?.headlineSet)
    }
}
