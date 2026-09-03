import XCTest
import SwiftData
@testable import KyleOS

final class FolderServiceTests: XCTestCase {
    private typealias Folder = FolderService.Folder

    func testCreateFolderStoresTitleAndKind() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let folder = FolderService.createFolder(title: "March Open Mics", kind: .sources, context: context)
        try context.save()

        XCTAssertEqual(folder.title, "March Open Mics")
        XCTAssertEqual(folder.kind, .sources)
        XCTAssertTrue(folder.sources.isEmpty)
        XCTAssertTrue(folder.clips.isEmpty)
    }

    func testMoveSourceAddsItToTheFolderAndRemovesItFromTheOldOne() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let folderA = FolderService.createFolder(title: "A", kind: .sources, context: context)
        let folderB = FolderService.createFolder(title: "B", kind: .sources, context: context)
        let source = SourceService.createSource(title: "Open Mic", context: context)
        try context.save()

        FolderService.moveSource(source, to: folderA)
        try context.save()
        XCTAssertEqual(source.folder?.id, folderA.id)
        XCTAssertEqual(folderA.sources.map(\.id), [source.id])

        FolderService.moveSource(source, to: folderB)
        try context.save()
        XCTAssertEqual(source.folder?.id, folderB.id)
        XCTAssertTrue(folderA.sources.isEmpty, "Moving to a new folder must remove it from the old one")
        XCTAssertEqual(folderB.sources.map(\.id), [source.id])
    }

    func testMoveSourceToNilUngroupsIt() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let folder = FolderService.createFolder(title: "A", kind: .sources, context: context)
        let source = SourceService.createSource(title: "Open Mic", context: context)
        FolderService.moveSource(source, to: folder)
        try context.save()

        FolderService.moveSource(source, to: nil)
        try context.save()

        XCTAssertNil(source.folder)
        XCTAssertTrue(folder.sources.isEmpty)
    }

    func testMoveClipAddsItToTheFolder() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let folder = FolderService.createFolder(title: "Airport Bit", kind: .clips, context: context)
        let clip = ClipService.createClip(title: "Take 1", context: context)
        try context.save()

        FolderService.moveClip(clip, to: folder)
        try context.save()

        XCTAssertEqual(clip.folder?.id, folder.id)
        XCTAssertEqual(folder.clips.map(\.id), [clip.id])
    }

    /// A Folder is purely organizational — deleting it must never delete the Sources/Clips inside,
    /// same "container doesn't own its contents' existence" reasoning as everywhere else in this
    /// codebase (CLAUDE.md §5).
    func testDeleteFolderLeavesItsSourcesAndClipsIntact() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let sourceFolder = FolderService.createFolder(title: "A", kind: .sources, context: context)
        let source = SourceService.createSource(title: "Open Mic", context: context)
        FolderService.moveSource(source, to: sourceFolder)
        let clipFolder = FolderService.createFolder(title: "Bit", kind: .clips, context: context)
        let clip = ClipService.createClip(title: "Take 1", context: context)
        FolderService.moveClip(clip, to: clipFolder)
        try context.save()

        FolderService.delete(sourceFolder, context: context)
        FolderService.delete(clipFolder, context: context)
        try context.save()

        let remainingFolders = try context.fetch(FetchDescriptor<Folder>())
        XCTAssertTrue(remainingFolders.isEmpty)
        let remainingSources = try context.fetch(FetchDescriptor<SourceService.Source>())
        XCTAssertEqual(remainingSources.map(\.id), [source.id])
        XCTAssertNil(remainingSources.first?.folder, "The Source must be detached, not left pointing at a deleted Folder")
        let remainingClips = try context.fetch(FetchDescriptor<ClipService.Clip>())
        XCTAssertEqual(remainingClips.map(\.id), [clip.id])
        XCTAssertNil(remainingClips.first?.folder)
    }

    func testDeletingASourceRemovesItFromItsFolderWithoutDeletingTheFolder() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let folder = FolderService.createFolder(title: "A", kind: .sources, context: context)
        let source = SourceService.createSource(title: "Open Mic", context: context)
        FolderService.moveSource(source, to: folder)
        try context.save()

        SourceService.delete(source, context: context)
        try context.save()

        let remainingFolders = try context.fetch(FetchDescriptor<Folder>())
        XCTAssertEqual(remainingFolders.count, 1)
        XCTAssertTrue(remainingFolders.first?.sources.isEmpty ?? false)
    }

    func testRenameUpdatesTitle() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let folder = FolderService.createFolder(title: "Old Name", kind: .clips, context: context)
        try context.save()

        FolderService.rename(folder, to: "New Name")
        try context.save()

        XCTAssertEqual(folder.title, "New Name")
    }
}
