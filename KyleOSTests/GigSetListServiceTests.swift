import XCTest
import SwiftData
@testable import KyleOS

final class GigSetListServiceTests: XCTestCase {

    func testAddJokeAndAddChunkAppendInOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        try context.save()

        GigSetListService.addJoke(joke, to: gig, context: context)
        GigSetListService.addChunk(chunk, to: gig, context: context)
        try context.save()

        let items = GigSetListService.items(in: gig)
        XCTAssertEqual(items.map(\.order), [0, 1])
        XCTAssertEqual(items[0].joke?.id, joke.id)
        XCTAssertEqual(items[1].chunk?.id, chunk.id)
    }

    func testItemTitleAndRuntimeReflectReferencedMaterial() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        joke.title = "Airline Food"
        joke.runtimeSeconds = 90
        try context.save()

        let item = GigSetListService.addJoke(joke, to: gig, context: context)
        try context.save()

        XCTAssertEqual(item.title, "Airline Food")
        XCTAssertEqual(item.runtimeSeconds, 90)
    }

    func testRemoveItemRenumbersRemaining() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        let jokeOne = JokeService.quickCapture(text: "Bit One", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Bit Two", context: context)
        let jokeThree = JokeService.quickCapture(text: "Bit Three", context: context)
        try context.save()
        GigSetListService.addJoke(jokeOne, to: gig, context: context)
        let middle = GigSetListService.addJoke(jokeTwo, to: gig, context: context)
        GigSetListService.addJoke(jokeThree, to: gig, context: context)
        try context.save()

        GigSetListService.removeItem(middle, from: gig, context: context)
        try context.save()

        let items = GigSetListService.items(in: gig)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.order), [0, 1])
        // Removing the set-list item must not delete the Joke it referenced.
        XCTAssertNotNil(try context.fetch(FetchDescriptor<GigSetListService.Joke>()).first { $0.id == jokeTwo.id })
    }

    func testReorderItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        let jokeOne = JokeService.quickCapture(text: "Bit One", context: context)
        let jokeTwo = JokeService.quickCapture(text: "Bit Two", context: context)
        try context.save()
        GigSetListService.addJoke(jokeOne, to: gig, context: context)
        GigSetListService.addJoke(jokeTwo, to: gig, context: context)
        try context.save()

        GigSetListService.reorderItems(in: gig, movingFromOffsets: IndexSet(integer: 1), toOffset: 0)
        try context.save()

        let items = GigSetListService.items(in: gig)
        XCTAssertEqual(items.map { $0.joke?.id }, [jokeTwo.id, jokeOne.id])
    }

    func testPlannedDurationRollsUpAcrossJokesAndChunksTreatingNilAsZero() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, setLengthMinutes: 5, context: context)
        let joke = JokeService.quickCapture(text: "Bit One", context: context)
        joke.runtimeSeconds = 60
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        chunk.runtimeSeconds = 120
        let untimedJoke = JokeService.quickCapture(text: "Untimed Bit", context: context)
        try context.save()

        GigSetListService.addJoke(joke, to: gig, context: context)
        GigSetListService.addChunk(chunk, to: gig, context: context)
        GigSetListService.addJoke(untimedJoke, to: gig, context: context)
        try context.save()

        XCTAssertEqual(GigSetListService.plannedDurationSeconds(for: gig), 180)
        XCTAssertEqual(GigSetListService.targetDurationSeconds(for: gig), 300)
    }

    func testDeletingReferencedJokeNullifiesRatherThanDeletingTheSetListItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        let joke = JokeService.quickCapture(text: "Bit One", context: context)
        try context.save()
        let item = GigSetListService.addJoke(joke, to: gig, context: context)
        let itemID = item.id
        try context.save()

        context.delete(joke)
        try context.save()

        let survivingItem = try context.fetch(FetchDescriptor<GigSetListService.GigSetListItem>()).first { $0.id == itemID }
        XCTAssertNotNil(survivingItem, "Deleting the referenced Joke must not delete the set-list row")
        XCTAssertNil(survivingItem?.joke)
        XCTAssertEqual(survivingItem?.title, "Removed material")
    }

    func testDeletingGigCascadeDeletesItsSetListItemsButNotTheReferencedJoke() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        let joke = JokeService.quickCapture(text: "Bit One", context: context)
        try context.save()
        let item = GigSetListService.addJoke(joke, to: gig, context: context)
        let itemID = item.id
        let jokeID = joke.id
        try context.save()

        GigService.delete(gig, context: context)
        try context.save()

        let remainingItems = try context.fetch(FetchDescriptor<GigSetListService.GigSetListItem>())
        XCTAssertFalse(remainingItems.contains { $0.id == itemID })
        let remainingJokes = try context.fetch(FetchDescriptor<GigSetListService.Joke>())
        XCTAssertTrue(remainingJokes.contains { $0.id == jokeID })
    }
}
