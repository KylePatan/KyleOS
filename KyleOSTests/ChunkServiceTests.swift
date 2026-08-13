import XCTest
import SwiftData
@testable import KyleOS

final class ChunkServiceTests: XCTestCase {

    func testCreateChunkAndRenameAndUpdateNotesPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let chunk = ChunkService.createChunk(title: "Airline Bit", context: context)
        try context.save()

        ChunkService.rename(chunk, to: "Travel Bit")
        ChunkService.updateNotes(chunk, notes: "Open with the cat joke.")
        try context.save()

        XCTAssertEqual(chunk.title, "Travel Bit")
        XCTAssertEqual(chunk.notes, "Open with the cat joke.")
    }

    func testAddJokeAppendsWithAscendingOrderWithinChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        let jokeOne = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        let jokeTwo = JokeService.quickCapture(text: "TSA is just cosplay.", context: context)
        try context.save()

        ChunkService.addJoke(jokeOne, to: chunk)
        ChunkService.addJoke(jokeTwo, to: chunk)
        try context.save()

        XCTAssertEqual(ChunkService.jokes(in: chunk).map(\.id), [jokeOne.id, jokeTwo.id])
        XCTAssertEqual(jokeOne.displayOrderWithinChunk, 0)
        XCTAssertEqual(jokeTwo.displayOrderWithinChunk, 1)
        XCTAssertEqual(jokeOne.chunk?.id, chunk.id)
    }

    func testAJokeCanExistIndependentlyOfAnyChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Loose idea.", context: context)
        try context.save()

        XCTAssertNil(joke.chunk)
        XCTAssertEqual(ChunkService.looseJokes(in: context).map(\.id), [joke.id])
    }

    func testRemoveJokeClearsRelationshipWithoutDeletingTheJoke() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        let jokeOne = JokeService.quickCapture(text: "One.", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Two.", context: context)
        try context.save()
        ChunkService.addJoke(jokeOne, to: chunk)
        ChunkService.addJoke(jokeTwo, to: chunk)
        try context.save()

        ChunkService.removeJoke(jokeOne, from: chunk)
        try context.save()

        XCTAssertNil(jokeOne.chunk, "Relationship removed...")
        XCTAssertNotNil(try context.fetch(FetchDescriptor<JokeService.Joke>()).first { $0.id == jokeOne.id }, "...but the Joke itself must still exist")
        XCTAssertEqual(ChunkService.jokes(in: chunk).map(\.id), [jokeTwo.id])
        XCTAssertEqual(jokeTwo.displayOrderWithinChunk, 0, "Remaining joke should renumber contiguously")
    }

    func testReorderJokesMovingLastToFirstRenumbersTheChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        let jokeOne = JokeService.quickCapture(text: "One.", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Two.", context: context)
        let jokeThree = JokeService.quickCapture(text: "Three.", context: context)
        try context.save()
        ChunkService.addJoke(jokeOne, to: chunk)
        ChunkService.addJoke(jokeTwo, to: chunk)
        ChunkService.addJoke(jokeThree, to: chunk)
        try context.save()

        ChunkService.reorderJokes(in: chunk, movingFromOffsets: IndexSet(integer: 2), toOffset: 0)
        try context.save()

        XCTAssertEqual(ChunkService.jokes(in: chunk).map(\.id), [jokeThree.id, jokeOne.id, jokeTwo.id])
    }

    func testMovingAJokeFromOneChunkToAnotherRenumbersTheOriginalChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunkA = ChunkService.createChunk(title: "Chunk A", context: context)
        let chunkB = ChunkService.createChunk(title: "Chunk B", context: context)
        let jokeOne = JokeService.quickCapture(text: "One.", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Two.", context: context)
        try context.save()
        ChunkService.addJoke(jokeOne, to: chunkA)
        ChunkService.addJoke(jokeTwo, to: chunkA)
        try context.save()

        ChunkService.addJoke(jokeOne, to: chunkB)
        try context.save()

        XCTAssertEqual(jokeOne.chunk?.id, chunkB.id)
        XCTAssertEqual(ChunkService.jokes(in: chunkA).map(\.id), [jokeTwo.id])
        XCTAssertEqual(jokeTwo.displayOrderWithinChunk, 0)
        XCTAssertEqual(ChunkService.jokes(in: chunkB).map(\.id), [jokeOne.id])
    }

    func testDeletingAChunkDoesNotDeleteItsMemberJokes() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        let joke = JokeService.quickCapture(text: "One.", context: context)
        try context.save()
        ChunkService.addJoke(joke, to: chunk)
        try context.save()

        ChunkService.delete(chunk, context: context)
        try context.save()

        let survivingJoke = try context.fetch(FetchDescriptor<JokeService.Joke>()).first { $0.id == joke.id }
        XCTAssertNotNil(survivingJoke, "PRD §7.6: deleting a Chunk must not delete its Jokes")
        XCTAssertNil(survivingJoke?.chunk)
    }
}
