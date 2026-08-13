import XCTest
import SwiftData
@testable import KyleOS

final class ClipServiceTests: XCTestCase {

    func testCreateClipDefaultsToIdentifiedToIsolate() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        try context.save()

        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        XCTAssertEqual(clip.status, .identifiedToIsolate)
        XCTAssertEqual(clip.source?.id, source.id)
        XCTAssertEqual(clip.progress, 0)
    }

    func testRenamePersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Draft Title", in: source, context: context)
        try context.save()

        ClipService.rename(clip, to: "Airline Bit")
        try context.save()

        XCTAssertEqual(clip.title, "Airline Bit")
    }

    func testUpdateDescriptionNotesEditingNotesAndTimestampsPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        ClipService.updateDescription(clip, description: "The airline food tag")
        ClipService.updateNotes(clip, notes: "Crowd loved this one")
        ClipService.updateEditingNotes(clip, notes: "Cut the dead air at 0:12")
        ClipService.updateTimestamps(clip, startSeconds: 125, endSeconds: 190)
        try context.save()

        XCTAssertEqual(clip.clipDescription, "The airline food tag")
        XCTAssertEqual(clip.notes, "Crowd loved this one")
        XCTAssertEqual(clip.editingNotes, "Cut the dead air at 0:12")
        XCTAssertEqual(clip.sourceTimestampStartSeconds, 125)
        XCTAssertEqual(clip.sourceTimestampEndSeconds, 190)
    }

    func testChangeStatusPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        ClipService.changeStatus(clip, to: .currentlyEditing)
        try context.save()

        XCTAssertEqual(clip.status, .currentlyEditing)
    }

    func testUpdateProgressClampsToZeroAndOneHundred() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        ClipService.updateProgress(clip, progress: 150)
        XCTAssertEqual(clip.progress, 100)

        ClipService.updateProgress(clip, progress: -10)
        XCTAssertEqual(clip.progress, 0)
    }

    func testSetPostDatePersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let postDate = Date(timeIntervalSince1970: 1_700_000_000)

        ClipService.setPostDate(clip, date: postDate)
        try context.save()

        XCTAssertEqual(clip.postDate, postDate)
    }

    func testLinkJokeAndChunkAreIndependentAndNullifyOnDelete() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        ClipService.linkJoke(clip, to: joke)
        try context.save()

        XCTAssertEqual(clip.joke?.id, joke.id)
        XCTAssertEqual(joke.clipAppearances.map(\.id), [clip.id])

        context.delete(joke)
        try context.save()

        let survivingClip = try context.fetch(FetchDescriptor<ClipService.Clip>()).first { $0.id == clip.id }
        XCTAssertNotNil(survivingClip, "Deleting the referenced Joke must not delete the Clip")
        XCTAssertNil(survivingClip?.joke)
    }

    func testClipsInSourceSortedByCreatedAt() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        try context.save()
        let first = ClipService.createClip(title: "First Clip", in: source, context: context)
        first.createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let second = ClipService.createClip(title: "Second Clip", in: source, context: context)
        second.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        let clips = ClipService.clips(in: source)

        XCTAssertEqual(clips.map(\.title), ["First Clip", "Second Clip"])
    }

    func testBoardLaneGroupsSevenStatusesIntoFiveLanes() {
        XCTAssertEqual(ClipService.boardLane(for: .identifiedToIsolate), .toIsolate)
        XCTAssertEqual(ClipService.boardLane(for: .footageIsolated), .editing)
        XCTAssertEqual(ClipService.boardLane(for: .currentlyEditing), .editing)
        XCTAssertEqual(ClipService.boardLane(for: .editedNotSubtitled), .needsSubtitles)
        XCTAssertEqual(ClipService.boardLane(for: .editedSubtitled), .ready)
        XCTAssertEqual(ClipService.boardLane(for: .ready), .ready)
        XCTAssertEqual(ClipService.boardLane(for: .posted), .posted)
    }

    func testClipsInLaneFiltersAcrossSources() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        try context.save()
        let toIsolate = ClipService.createClip(title: "To Isolate Clip", in: source, context: context)
        let editing = ClipService.createClip(title: "Editing Clip", in: source, context: context)
        ClipService.changeStatus(editing, to: .currentlyEditing)
        try context.save()

        let toIsolateLane = ClipService.clips(inLane: .toIsolate, in: context)
        let editingLane = ClipService.clips(inLane: .editing, in: context)

        XCTAssertEqual(toIsolateLane.map(\.id), [toIsolate.id])
        XCTAssertEqual(editingLane.map(\.id), [editing.id])
    }

    func testDeleteClipDoesNotDeleteItsSource() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let sourceID = source.id

        ClipService.delete(clip, context: context)
        try context.save()

        let survivingSource = try context.fetch(FetchDescriptor<SourceService.Source>()).first { $0.id == sourceID }
        XCTAssertNotNil(survivingSource)
        XCTAssertTrue(ClipService.clips(in: survivingSource!).isEmpty)
    }
}
