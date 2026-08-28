import XCTest
import SwiftData
@testable import KyleOS

final class WorkItemPersistenceTests: XCTestCase {

    /// Real bug Kyle hit: "I deleted the source and that should delete the 'clips' within it, no?"
    /// — it did (Source cascades to Clip), but the Clip's own "Post" WorkItem/Deadline was left
    /// behind, undeletable, since `Clip.workItems` is deliberately `.nullify` not `.cascade` (a
    /// WorkItem is session/time-tracking history that outlives its target — see that relationship's
    /// own doc comment). `deleteUnderlyingContent` must fall back to removing the orphaned WorkItem
    /// row itself once its target is gone, not silently no-op.
    func testDeleteUnderlyingContentRemovesAnOrphanedWorkItemAfterItsClipIsAlreadyGone() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airplane Joke", in: source, context: context)
        let workItem = try WorkItemService.clipPostingWorkItem(for: clip, context: context)
        try context.save()

        SourceService.delete(source, context: context) // cascades away the Clip, nullifies workItem.clip
        try context.save()
        XCTAssertNil(workItem.clip, "Sanity check: the Clip is really gone, only the WorkItem remains")
        XCTAssertNil(WorkItemService.underlyingContent(for: workItem))

        WorkItemService.deleteUnderlyingContent(for: workItem, context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkItemService.WorkItem>()).isEmpty, "The orphaned WorkItem itself must be removable")
    }

    /// Same fallback, for a genuinely general Stand-Up session that never had real content —
    /// Kyle: "also stand up writing... is unable to be deleted."
    func testDeleteUnderlyingContentRemovesAGeneralStandUpSession() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try WorkItemService.generalStandUpWorkItem(context: context)
        try context.save()

        WorkItemService.deleteUnderlyingContent(for: workItem, context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkItemService.WorkItem>()).isEmpty)
    }

    /// New 2026-08-20 (real use, "the things on 'home' should be removeable") — Home's Weekly
    /// Board/All Tasks rows only ever show a WorkItem, so deleting/archiving what they represent
    /// has to resolve past it to the real content first. A Writing WorkItem carries `project`, so
    /// deleting it must reach the whole Project (matching WritingHomeView's own row action), not
    /// just detach the WorkItem.
    func testUnderlyingContentAndDeleteForAWritingWorkItemResolvesToItsProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "test", in: context)
        let document = DocumentService.createDocument(title: "Untitled", type: .prose, in: project, context: context)
        let workItem = try WorkItemService.writingWorkItem(for: document, context: context)
        try context.save()

        guard case .project(let resolved) = WorkItemService.underlyingContent(for: workItem) else {
            return XCTFail("Expected .project")
        }
        XCTAssertEqual(resolved.id, project.id)
        XCTAssertNotNil(WorkItemService.archiveUnderlyingContent(for: workItem), "A Project can be archived")

        WorkItemService.deleteUnderlyingContent(for: workItem, context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<ProjectService.Project>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkItemService.WorkItem>()).isEmpty, "Must cascade-delete along with the Project")
    }

    func testUnderlyingContentForAChunkWorkItemHasNoArchiveActionButStillDeletes() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Airport Bit", context: context)
        let workItem = try WorkItemService.standUpWorkItem(for: chunk, context: context)
        try context.save()

        guard case .chunk(let resolved) = WorkItemService.underlyingContent(for: workItem) else {
            return XCTFail("Expected .chunk")
        }
        XCTAssertEqual(resolved.id, chunk.id)
        XCTAssertNil(WorkItemService.archiveUnderlyingContent(for: workItem), "Chunk has no archive concept of its own")

        WorkItemService.deleteUnderlyingContent(for: workItem, context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<ChunkService.Chunk>()).isEmpty)
    }

    func testUnderlyingContentForAGeneralStandUpSessionIsNil() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try WorkItemService.generalStandUpWorkItem(context: context)
        try context.save()

        XCTAssertNil(WorkItemService.underlyingContent(for: workItem), "A general session has nothing to archive or delete")
        XCTAssertNil(WorkItemService.archiveUnderlyingContent(for: workItem))
    }

    func testWritingWorkItemCreatesOneLinkedToTheDocumentOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)

        let workItem = try WorkItemService.writingWorkItem(for: document, context: context)
        try context.save()

        XCTAssertEqual(workItem.document?.id, document.id)
        XCTAssertEqual(workItem.workspace, .writing)
        XCTAssertEqual(workItem.title, "Chapter One")
    }

    func testWritingWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        // createsWritingTask: false — isolates this test to writingWorkItem's own idempotency;
        // the placeholder-retirement interaction has its own dedicated test below.
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, createsWritingTask: false, in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)

        let first = try WorkItemService.writingWorkItem(for: document, context: context)
        try context.save()
        let second = try WorkItemService.writingWorkItem(for: document, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1, "A second call must not create a duplicate")
    }

    /// Kyle (2026-08-27): "why isn't hackers sketch showing up in my to do?" led to
    /// `ProjectService.createProject` auto-creating a placeholder WorkItem for every Project —
    /// which then risks sitting alongside a real Document-level WorkItem as a duplicate,
    /// permanently-incomplete task the moment Kyle actually starts writing. This is the fix:
    /// starting real work retires the placeholder instead of leaving it stranded.
    func testWritingWorkItemRetiresThePlaceholderProjectLevelWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        let placeholder = try XCTUnwrap(try WorkItemService.workItems(for: project, in: context).first)
        XCTAssertEqual(placeholder.workTypeName, "Short Story Writing")
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)

        let realWorkItem = try WorkItemService.writingWorkItem(for: document, context: context)
        try context.save()

        XCTAssertEqual(placeholder.status, .completed, "The placeholder must be retired once real work is tracked")
        XCTAssertEqual(realWorkItem.status, .notStarted, "Only the placeholder is retired, not the new real WorkItem")
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 2)
    }

    func testStandUpWorkItemForJokeCreatesOneLinkedToTheJokeOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
        try context.save()

        XCTAssertEqual(workItem.joke?.id, joke.id)
        XCTAssertNil(workItem.chunk)
        XCTAssertNil(workItem.project)
        XCTAssertEqual(workItem.workspace, .standUp)
    }

    func testStandUpWorkItemForJokeReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        let first = try WorkItemService.standUpWorkItem(for: joke, context: context)
        try context.save()
        let second = try WorkItemService.standUpWorkItem(for: joke, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testStandUpWorkItemForChunkCreatesOneLinkedToTheChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        try context.save()

        let workItem = try WorkItemService.standUpWorkItem(for: chunk, context: context)
        try context.save()

        XCTAssertEqual(workItem.chunk?.id, chunk.id)
        XCTAssertNil(workItem.joke)
        XCTAssertEqual(workItem.title, "Travel Bit")
    }

    func testGeneralStandUpWorkItemHasNoJokeOrChunkAndIsReused() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let first = try WorkItemService.generalStandUpWorkItem(context: context)
        try context.save()
        let second = try WorkItemService.generalStandUpWorkItem(context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertNil(first.joke)
        XCTAssertNil(first.chunk)
        XCTAssertEqual(first.workspace, .standUp)
        XCTAssertEqual(first.title, "Stand-Up Writing")
    }

    func testGeneralStandUpWorkItemIsDistinctFromAJokeSpecificWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        let general = try WorkItemService.generalStandUpWorkItem(context: context)
        let jokeSpecific = try WorkItemService.standUpWorkItem(for: joke, context: context)

        XCTAssertNotEqual(general.id, jokeSpecific.id)
    }

    func testDeletingJokeNullifiesRatherThanDeletingItsWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()
        let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
        let workItemID = workItem.id
        try context.save()

        context.delete(joke)
        try context.save()

        let survivingWorkItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        let survivor = survivingWorkItems.first { $0.id == workItemID }
        XCTAssertNotNil(survivor, "Deleting the Joke must not delete its logged Work Item history")
        XCTAssertNil(survivor?.joke)
    }

    func testClipWorkItemCreatesOneLinkedToTheClipOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let workItem = try WorkItemService.clipWorkItem(for: clip, context: context)
        try context.save()

        XCTAssertEqual(workItem.clip?.id, clip.id)
        XCTAssertNil(workItem.project)
        XCTAssertEqual(workItem.workspace, .clips)
        XCTAssertEqual(workItem.title, "Airline Bit")
    }

    func testClipWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let first = try WorkItemService.clipWorkItem(for: clip, context: context)
        try context.save()
        let second = try WorkItemService.clipWorkItem(for: clip, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testDeletingClipNullifiesRatherThanDeletingItsWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let workItem = try WorkItemService.clipWorkItem(for: clip, context: context)
        let workItemID = workItem.id
        try context.save()

        ClipService.delete(clip, context: context)
        try context.save()

        let survivingWorkItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        let survivor = survivingWorkItems.first { $0.id == workItemID }
        XCTAssertNotNil(survivor, "Deleting the Clip must not delete its logged Work Item history")
        XCTAssertNil(survivor?.clip)
    }

    // MARK: - Clip stage WorkItems (2026-08-17: separate deadlines per production stage)

    func testClipSubtitlingWorkItemIsDistinctFromClipEditingWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let editing = try WorkItemService.clipWorkItem(for: clip, context: context)
        let subtitling = try WorkItemService.clipSubtitlingWorkItem(for: clip, context: context)
        try context.save()

        XCTAssertNotEqual(editing.id, subtitling.id)
        XCTAssertEqual(editing.workTypeName, "Clip Editing")
        XCTAssertEqual(subtitling.workTypeName, "Clip Subtitling")
        XCTAssertEqual(subtitling.clip?.id, clip.id)
    }

    func testClipSubtitlingWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let first = try WorkItemService.clipSubtitlingWorkItem(for: clip, context: context)
        try context.save()
        let second = try WorkItemService.clipSubtitlingWorkItem(for: clip, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testClipPostingWorkItemIsDistinctFromEditingAndSubtitling() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let editing = try WorkItemService.clipWorkItem(for: clip, context: context)
        let subtitling = try WorkItemService.clipSubtitlingWorkItem(for: clip, context: context)
        let posting = try WorkItemService.clipPostingWorkItem(for: clip, context: context)
        try context.save()

        let allIDs = Set([editing.id, subtitling.id, posting.id])
        XCTAssertEqual(allIDs.count, 3, "Editing, Subtitling, and Posting must each get their own WorkItem")
        XCTAssertEqual(posting.workTypeName, "Clip Posting")
    }

    func testEditingAndSubtitlingDeadlinesOnTheSameClipAreIndependent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let editing = try WorkItemService.clipWorkItem(for: clip, context: context)
        let subtitling = try WorkItemService.clipSubtitlingWorkItem(for: clip, context: context)
        let editingDue = Date(timeIntervalSinceNow: 86400 * 2)
        let subtitlingDue = Date(timeIntervalSinceNow: 86400 * 5)
        DeadlineService.setDeadline(for: editing, label: "Finish editing", dueAt: editingDue, context: context)
        DeadlineService.setDeadline(for: subtitling, label: "Finish subtitling", dueAt: subtitlingDue, context: context)
        try context.save()

        let editingDeadline = try XCTUnwrap(editing.deadline)
        let subtitlingDeadline = try XCTUnwrap(subtitling.deadline)
        XCTAssertEqual(editingDeadline.dueAt.timeIntervalSince1970, editingDue.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(subtitlingDeadline.dueAt.timeIntervalSince1970, subtitlingDue.timeIntervalSince1970, accuracy: 1)
        XCTAssertNotEqual(editingDeadline.id, subtitlingDeadline.id)
    }

    /// Kyle (2026-08-20): "when a new piece of sketch writing is created - shouldn't it go on the
    /// home board?" — the pre-production counterpart to sketchEditingWorkItem, so a brand-new
    /// (not-yet-finished) Sketch has something representing it on Home immediately. Generalized
    /// 2026-08-27 to every Project type — see `testCreateProjectCreatesAWritingWorkItemFor...`
    /// below for `createProject`'s own now-automatic side effect; these two exercise
    /// `projectWritingWorkItem` directly, independent of that.
    func testProjectWritingWorkItemCreatesOneLinkedToTheProjectOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Hackers Sketch", projectType: .sketch, createsWritingTask: false, in: context)
        try context.save()

        let workItem = try WorkItemService.projectWritingWorkItem(for: project, context: context)
        try context.save()

        XCTAssertEqual(workItem.project?.id, project.id)
        XCTAssertEqual(workItem.workspace, .writing, "Pre-production is writing-phase work, not sketches production")
        XCTAssertEqual(workItem.title, "Hackers Sketch")
        XCTAssertEqual(workItem.workTypeName, "Sketch Writing")
    }

    func testProjectWritingWorkItemDerivesWorkTypeNameFromTheProjectsOwnType() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let pilot = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, createsWritingTask: false, in: context)
        let untyped = ProjectService.createProject(title: "Untitled Idea", createsWritingTask: false, in: context)
        try context.save()

        let pilotWorkItem = try WorkItemService.projectWritingWorkItem(for: pilot, context: context)
        let untypedWorkItem = try WorkItemService.projectWritingWorkItem(for: untyped, context: context)

        XCTAssertEqual(pilotWorkItem.workTypeName, "TV Pilot Writing")
        XCTAssertEqual(untypedWorkItem.workTypeName, "Project Writing", "A type-less Quick Add project falls back to a generic name")
    }

    func testProjectWritingWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Hackers Sketch", projectType: .sketch, createsWritingTask: false, in: context)
        try context.save()

        let first = try WorkItemService.projectWritingWorkItem(for: project, context: context)
        try context.save()
        let second = try WorkItemService.projectWritingWorkItem(for: project, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1)
    }

    /// Kyle (2026-08-27, real use): "why isn't hackers sketch showing up in my to do? ... i feel
    /// like every project in terms of priority should be in my to do... whatever project I create
    /// can go into the To Do." `createProject` itself now creates this by default — no creation
    /// flow can forget to wire it up.
    func testCreateProjectCreatesAWritingWorkItemByDefault() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Coastal Town", projectType: .screenplay, in: context)
        try context.save()

        let items = try WorkItemService.workItems(for: project, in: context)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.workTypeName, "Screenplay Writing")
        XCTAssertEqual(items.first?.workspace, .writing)
    }

    /// `NewSketchSheet`'s Reel path: its real work happens on the linked Clip instead, so a
    /// spurious, permanently-incomplete "Sketch Writing" task must not also be created.
    func testCreateProjectSkipsTheWritingWorkItemWhenCreatesWritingTaskIsFalse() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Reel", projectType: .sketch, createsWritingTask: false, in: context)
        try context.save()

        XCTAssertTrue(try WorkItemService.workItems(for: project, in: context).isEmpty)
    }

    /// A project created already-finished has nothing left to write — matches
    /// `backfillProjectWritingWorkItems`'s own finished-project exclusion.
    func testCreateProjectSkipsTheWritingWorkItemForAnAlreadyFinishedProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        XCTAssertTrue(try WorkItemService.workItems(for: project, in: context).isEmpty)
    }

    /// The actual "hackers sketch" bug: a Project that predates the automatic-WorkItem fix (or
    /// was created some other way that never called `projectWritingWorkItem`) has zero WorkItems.
    /// `backfillProjectWritingWorkItems` — run once at every launch, `KyleOSApp.init()` — catches
    /// it retroactively.
    func testBackfillProjectWritingWorkItemsCatchesAPreExistingProjectWithNoWorkItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Hackers Sketch", projectType: .sketch, createsWritingTask: false, in: context)
        try context.save()
        XCTAssertTrue(try WorkItemService.workItems(for: project, in: context).isEmpty, "Sanity check: this reproduces the real bug's starting state")

        try WorkItemService.backfillProjectWritingWorkItems(in: context)
        try context.save()

        let items = try WorkItemService.workItems(for: project, in: context)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.workTypeName, "Sketch Writing")
    }

    func testBackfillProjectWritingWorkItemsSkipsAProjectThatAlreadyHasOne() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        try context.save()
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1)

        try WorkItemService.backfillProjectWritingWorkItems(in: context)
        try context.save()

        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1, "Must not create a duplicate task")
    }

    func testBackfillProjectWritingWorkItemsSkipsAReel() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Reel", projectType: .sketch, createsWritingTask: false, in: context)
        _ = SketchProductionService.markAsReel(project, context: context)
        try context.save()

        try WorkItemService.backfillProjectWritingWorkItems(in: context)
        try context.save()

        XCTAssertTrue(try WorkItemService.workItems(for: project, in: context).isEmpty, "A Reel's work happens on its linked Clip, not a Sketch Writing task")
    }

    func testBackfillProjectWritingWorkItemsSkipsFinishedAndArchivedProjects() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let finished = ProjectService.createProject(title: "Finished Bit", projectType: .other, status: .finished, in: context)
        let archived = ProjectService.createProject(title: "Old Idea", projectType: .other, createsWritingTask: false, in: context)
        ProjectService.archive(archived)
        try context.save()

        try WorkItemService.backfillProjectWritingWorkItems(in: context)
        try context.save()

        XCTAssertTrue(try WorkItemService.workItems(for: finished, in: context).isEmpty)
        XCTAssertTrue(try WorkItemService.workItems(for: archived, in: context).isEmpty)
    }

    func testSketchEditingWorkItemCreatesOneLinkedToTheProjectOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        let workItem = try WorkItemService.sketchEditingWorkItem(for: project, context: context)
        try context.save()

        XCTAssertEqual(workItem.project?.id, project.id)
        XCTAssertEqual(workItem.workspace, .sketches)
        XCTAssertEqual(workItem.title, "Airport Sketch")
        XCTAssertEqual(workItem.workTypeName, "Sketch Editing")
    }

    func testSketchEditingWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        let first = try WorkItemService.sketchEditingWorkItem(for: project, context: context)
        try context.save()
        let second = try WorkItemService.sketchEditingWorkItem(for: project, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1, "A second call must not create a duplicate")
    }

    func testCreatingAWorkItemSeedsEstimateFromMatchingWorkTypeDefault() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
        try context.save()

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1",
            workspace: .writing,
            workTypeName: "Outline",
            in: project,
            context: context
        )
        try context.save()

        // PRD §5.1: Outline defaults to 1.5 creative hours = 90 minutes.
        XCTAssertEqual(workItem.estimatedTotalMinutes, 90)
        XCTAssertEqual(workItem.estimatedRemainingMinutes, 90)
        XCTAssertEqual(workItem.status, .notStarted)
        XCTAssertEqual(workItem.progress, 0)
    }

    func testCreatingAWorkItemWithUnknownWorkTypeFallsBackToGenericDefaults() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Something new",
            workspace: .clips,
            workTypeName: "Never Seeded Type",
            in: project,
            context: context
        )
        try context.save()

        XCTAssertEqual(workItem.estimatedTotalMinutes, 60)
        XCTAssertEqual(workItem.preferredSessionMinutes, 45)
        XCTAssertEqual(workItem.minimumSessionMinutes, 15)
    }

    func testUpdateProgressMovesNotStartedToInProgressButNotToCompleted() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.updateProgress(workItem, progress: 100, context: context)
        try context.save()

        XCTAssertEqual(workItem.progress, 100)
        XCTAssertEqual(workItem.status, .inProgress, "Progress alone must not auto-complete a Work Item")
        XCTAssertNil(workItem.completedAt)
    }

    func testProgressClampsToZeroAndOneHundred() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )

        WorkItemService.updateProgress(workItem, progress: 150, context: context)
        XCTAssertEqual(workItem.progress, 100)

        WorkItemService.updateProgress(workItem, progress: -20, context: context)
        XCTAssertEqual(workItem.progress, 0)
    }

    func testCompleteSetsStatusProgressAndCompletionDate() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.complete(workItem, context: context)
        try context.save()

        XCTAssertEqual(workItem.status, .completed)
        XCTAssertEqual(workItem.progress, 100)
        XCTAssertNotNil(workItem.completedAt)
    }

    func testPriorityAndDependenciesPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let outline = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let draft = try WorkItemService.createWorkItem(
            title: "First Draft", workspace: .writing, workTypeName: "Script Draft", in: project, context: context
        )
        WorkItemService.setPriority(draft, to: 5)
        WorkItemService.addDependency(draft, dependsOn: outline)
        try context.save()

        XCTAssertEqual(draft.priority, 5)
        XCTAssertEqual(draft.dependsOn.map(\.id), [outline.id])

        WorkItemService.removeDependency(draft, dependency: outline)
        try context.save()
        XCTAssertTrue(draft.dependsOn.isEmpty)
    }

    func testDeletingProjectCascadesToItsWorkItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        XCTAssertEqual(remaining.count, 0, "Deleting a Project must cascade-delete its Work Items")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSWorkItemRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let workItemID: UUID
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            // createsWritingTask: false — this test is about restart persistence of the
            // explicitly-created WorkItem below, not `createProject`'s own auto-placeholder.
            let project = ProjectService.createProject(title: "Untitled Pilot", createsWritingTask: false, in: context)
            let workItem = try WorkItemService.createWorkItem(
                title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
            )
            WorkItemService.updateProgress(workItem, progress: 40, context: context)
            workItemID = workItem.id
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let allItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
            XCTAssertEqual(allItems.count, 1)
            XCTAssertEqual(allItems.first?.id, workItemID)
            XCTAssertEqual(allItems.first?.progress, 40)
            XCTAssertEqual(allItems.first?.status, .inProgress)
            XCTAssertNotNil(allItems.first?.project, "The Project relationship must survive a restart")
        }
    }
}
