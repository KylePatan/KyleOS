import XCTest
import SwiftData
@testable import KyleOS

final class FileReferenceResolverTests: XCTestCase {

    private func makeTempFile(named name: String = "clip.mov", in dir: URL? = nil) throws -> (fileURL: URL, dir: URL) {
        let directory = dir ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        if dir == nil {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let fileURL = directory.appendingPathComponent(name)
        try "fake media bytes".write(to: fileURL, atomically: true, encoding: .utf8)
        return (fileURL, directory)
    }

    func testResolveReturnsAvailableWhenFileExists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (fileURL, dir) = try makeTempFile()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let reference = try FileReferenceService.create(displayName: "Clip", fileURL: fileURL, context: context)

        // Not a raw string comparison against fileURL.path: bookmark resolution returns the
        // canonical /private/var/... form while FileManager.temporaryDirectory hands back the
        // /var/... symlinked form, a cosmetic difference. What matters is that resolution
        // succeeds and genuinely points at the same file on disk.
        guard case .available(let resolvedPath) = FileReferenceResolver.resolve(reference) else {
            return XCTFail("Expected .available, got a different resolution")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolvedPath))
        XCTAssertEqual(URL(fileURLWithPath: resolvedPath).lastPathComponent, fileURL.lastPathComponent)
    }

    func testResolveReturnsMissingWhenFileDeleted() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (fileURL, dir) = try makeTempFile()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let reference = try FileReferenceService.create(displayName: "Clip", fileURL: fileURL, context: context)
        try FileManager.default.removeItem(at: fileURL)

        XCTAssertEqual(FileReferenceResolver.resolve(reference), .missing)
    }

    func testResolveReturnsNoBookmarkDataWhenNoneStored() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let bare = KyleOSSchemaV12.FileReference(displayName: "No bookmark", originalPath: "/nowhere", bookmarkData: nil)
        context.insert(bare)

        XCTAssertEqual(FileReferenceResolver.resolve(bare), .noBookmarkData)
    }

    func testCheckAvailabilitySurvivesTemporaryUnavailabilityWithoutLosingMetadata() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (fileURL, dir) = try makeTempFile()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let reference = try FileReferenceService.create(
            displayName: "Comedy Slam Clip", fileURL: fileURL, notes: "Important footage", context: context
        )
        try context.save()

        // Simulate a disconnected drive: the source file disappears.
        try FileManager.default.removeItem(at: fileURL)
        let stillAvailable = FileReferenceResolver.checkAvailability(reference)

        XCTAssertFalse(stillAvailable)
        XCTAssertFalse(reference.lastKnownAvailable)
        XCTAssertNotNil(reference.lastCheckedAt)
        // The metadata itself must be untouched — this IS "survives temporary unavailability."
        XCTAssertEqual(reference.displayName, "Comedy Slam Clip")
        XCTAssertEqual(reference.notes, "Important footage")
        XCTAssertNotNil(reference.bookmarkData)
    }

    func testCheckAvailabilityRecoversWhenFileReappears() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (fileURL, dir) = try makeTempFile()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let reference = try FileReferenceService.create(displayName: "Clip", fileURL: fileURL, context: context)
        try FileManager.default.removeItem(at: fileURL)
        XCTAssertFalse(FileReferenceResolver.checkAvailability(reference))

        // The "drive" is reconnected — same path becomes valid again.
        try "fake media bytes".write(to: fileURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileReferenceResolver.checkAvailability(reference))
        XCTAssertTrue(reference.lastKnownAvailable)
    }

    func testFileMovedWithinSameVolumeStillResolvesViaBookmark() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (fileURL, dir) = try makeTempFile()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let reference = try FileReferenceService.create(displayName: "Clip", fileURL: fileURL, context: context)

        let movedURL = dir.appendingPathComponent("renamed_clip.mov")
        try FileManager.default.moveItem(at: fileURL, to: movedURL)

        let available = FileReferenceResolver.checkAvailability(reference)

        XCTAssertTrue(available, "A macOS bookmark should still resolve after the file is renamed within the same volume")
        // Same cosmetic /var vs /private/var difference as above — check the file is genuinely
        // reachable at the refreshed path and points at the renamed file, not the string form.
        XCTAssertTrue(FileManager.default.fileExists(atPath: reference.originalPath))
        XCTAssertEqual(URL(fileURLWithPath: reference.originalPath).lastPathComponent, "renamed_clip.mov", "The stored path should refresh to the new location")
    }
}
