import XCTest
import SwiftData
@testable import KyleOS

final class JokeServiceTests: XCTestCase {

    func testQuickCaptureCreatesAnIdeaWithAscendingOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let first = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        let second = JokeService.quickCapture(text: "Group chats are just group texts with anxiety.", context: context)
        try context.save()

        XCTAssertEqual(first.status, .ideas)
        XCTAssertEqual(first.order, 0)
        XCTAssertEqual(second.order, 1)
        XCTAssertEqual(first.title, "", "PRD §7.3: quick capture requires only the idea text")
    }

    func testJokesWithStatusExcludesArchivedAndOtherStatuses() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let idea = JokeService.quickCapture(text: "Idea one.", context: context)
        let other = JokeService.quickCapture(text: "Idea two.", context: context)
        try context.save()
        JokeService.move(other, to: .new, in: context)
        let archived = JokeService.quickCapture(text: "Old idea.", context: context)
        JokeService.archive(archived)
        try context.save()

        XCTAssertEqual(JokeService.jokes(withStatus: .ideas, in: context).map(\.id), [idea.id])
    }

    func testRenameAndUpdateTextPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Working version.", context: context)
        try context.save()

        JokeService.rename(joke, title: "Cat Food Bit")
        JokeService.updateText(joke, text: "Final version of the bit.")
        try context.save()

        XCTAssertEqual(joke.title, "Cat Food Bit")
        XCTAssertEqual(joke.text, "Final version of the bit.")
    }

    func testMoveToStatusAppendsToDestinationAndRenumbersSource() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let jokeOne = JokeService.quickCapture(text: "One.", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Two.", context: context)
        let jokeThree = JokeService.quickCapture(text: "Three.", context: context)
        try context.save()

        JokeService.move(jokeTwo, to: .new, in: context)
        try context.save()

        XCTAssertEqual(JokeService.jokes(withStatus: .ideas, in: context).map(\.id), [jokeOne.id, jokeThree.id])
        XCTAssertEqual(jokeOne.order, 0)
        XCTAssertEqual(jokeThree.order, 1, "Source column should renumber contiguously after losing a joke")
        XCTAssertEqual(JokeService.jokes(withStatus: .new, in: context).map(\.id), [jokeTwo.id])
        XCTAssertEqual(jokeTwo.status, .new)
        XCTAssertEqual(jokeTwo.order, 0)
    }

    func testMoveToTheSameStatusIsANoOp() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "One.", context: context)
        try context.save()
        let originalUpdatedAt = joke.updatedAt

        JokeService.move(joke, to: .ideas, in: context)

        XCTAssertEqual(joke.order, 0)
        XCTAssertEqual(joke.updatedAt, originalUpdatedAt)
    }

    func testReorderMovingLastJokeToFirstRenumbersTheColumn() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let jokeOne = JokeService.quickCapture(text: "One.", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Two.", context: context)
        let jokeThree = JokeService.quickCapture(text: "Three.", context: context)
        try context.save()

        JokeService.reorder(withStatus: .ideas, movingFromOffsets: IndexSet(integer: 2), toOffset: 0, in: context)
        try context.save()

        XCTAssertEqual(JokeService.jokes(withStatus: .ideas, in: context).map(\.id), [jokeThree.id, jokeOne.id, jokeTwo.id])
    }

    func testArchiveAndRestore() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "One.", context: context)
        try context.save()

        JokeService.archive(joke)
        try context.save()
        XCTAssertTrue(joke.isArchived)
        XCTAssertNotNil(joke.archivedAt)
        XCTAssertTrue(JokeService.jokes(withStatus: .ideas, in: context).isEmpty)

        JokeService.restore(joke)
        try context.save()
        XCTAssertFalse(joke.isArchived)
        XCTAssertNil(joke.archivedAt)
        XCTAssertEqual(JokeService.jokes(withStatus: .ideas, in: context).map(\.id), [joke.id])
    }

    /// New 2026-08-20 (real use) — the permanent counterpart to Archive, same as
    /// ChunkService.delete/ClipService.delete already had.
    func testDeletePermanentlyRemovesTheJoke() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "One.", context: context)
        try context.save()

        JokeService.delete(joke, context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<JokeService.Joke>()).isEmpty)
    }
}
