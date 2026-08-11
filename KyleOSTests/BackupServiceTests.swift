import XCTest
import SwiftData
@testable import KyleOS

/// Uses real temp directories and real ModelContainers throughout — never the shared real store
/// (~/Library/Application Support/...), per the lesson from prior sessions about not touching
/// that location from tests. Backup is fundamentally a file-copy operation, so these tests need
/// genuine files on disk, not just in-memory SwiftData.
final class BackupServiceTests: XCTestCase {

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    /// The store filename SwiftData's default (unnamed) ModelConfiguration always uses.
    private func makeStore(in directory: URL) throws -> (container: ModelContainer, projectID: UUID) {
        let container = try ModelContainer(
            for: PersistenceController.schema,
            migrationPlan: KyleOSMigrationPlan.self,
            configurations: [ModelConfiguration(url: directory.appendingPathComponent("default.store"))]
        )
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try context.save()
        return (container, project.id)
    }

    func testCreateBackupThrowsWhenNoStoreExists() throws {
        let storeDir = try makeTempDirectory()
        let backupsDir = try makeTempDirectory()

        XCTAssertThrowsError(try BackupService.createBackup(storeDirectory: storeDir, backupsDirectory: backupsDir)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .sourceStoreNotFound)
        }
    }

    func testCreateBackupCopiesStoreFilesAndTheyRemainOpenable() throws {
        let storeDir = try makeTempDirectory()
        let backupsDir = try makeTempDirectory()
        let (_, projectID) = try makeStore(in: storeDir)

        let backupLocation = try BackupService.createBackup(storeDirectory: storeDir, backupsDirectory: backupsDir)
        try FileManager.default.contentsOfDirectory(atPath: storeDir.path) // sanity: source still readable

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupLocation.appendingPathComponent("default.store").path))

        // The backup must be a genuine, independently-openable copy — not just bytes that
        // happen to match.
        let restoredContainer = try ModelContainer(
            for: PersistenceController.schema,
            migrationPlan: KyleOSMigrationPlan.self,
            configurations: [ModelConfiguration(url: backupLocation.appendingPathComponent("default.store"))]
        )
        let restoredContext = ModelContext(restoredContainer)
        let projects = try ProjectService.activeProjects(in: restoredContext)
        XCTAssertEqual(projects.map(\.id), [projectID])
    }

    func testRestoreBackupBringsDataBackAfterSimulatedLoss() throws {
        let storeDir = try makeTempDirectory()
        let backupsDir = try makeTempDirectory()
        let (container, projectID) = try makeStore(in: storeDir)
        var originalContainer: ModelContainer? = container
        let backupLocation = try BackupService.createBackup(storeDirectory: storeDir, backupsDirectory: backupsDir)

        // Simulate data loss: actually release the open container (not just discard the
        // reference — `let _ = x` wouldn't deallocate it), then destroy the live store files
        // as if the disk were corrupted or the user deleted them.
        originalContainer = nil
        for fileURL in BackupService.storeFileURLs(in: storeDir) {
            try FileManager.default.removeItem(at: fileURL)
        }
        XCTAssertTrue(BackupService.storeFileURLs(in: storeDir).isEmpty, "Precondition: the live store must actually be gone")

        try BackupService.restoreBackup(from: backupLocation, to: storeDir)

        let recoveredContainer = try ModelContainer(
            for: PersistenceController.schema,
            migrationPlan: KyleOSMigrationPlan.self,
            configurations: [ModelConfiguration(url: storeDir.appendingPathComponent("default.store"))]
        )
        let recoveredContext = ModelContext(recoveredContainer)
        let projects = try ProjectService.activeProjects(in: recoveredContext)
        XCTAssertEqual(projects.map(\.id), [projectID], "Restoring a backup must bring the original data back")
    }

    func testRestoreBackupThrowsWhenBackupIsEmpty() throws {
        let emptyBackup = try makeTempDirectory()
        let storeDir = try makeTempDirectory()

        XCTAssertThrowsError(try BackupService.restoreBackup(from: emptyBackup, to: storeDir)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .sourceStoreNotFound)
        }
    }

    func testListBackupsReturnsCreatedBackupsNewestFirst() throws {
        let storeDir = try makeTempDirectory()
        let backupsDir = try makeTempDirectory()
        _ = try makeStore(in: storeDir)

        let earlier = try BackupService.createBackup(
            storeDirectory: storeDir, backupsDirectory: backupsDir, at: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let later = try BackupService.createBackup(
            storeDirectory: storeDir, backupsDirectory: backupsDir, at: Date(timeIntervalSince1970: 1_700_100_000)
        )

        let backups = BackupService.listBackups(in: backupsDir)
        XCTAssertEqual(backups.map(\.lastPathComponent), [later.lastPathComponent, earlier.lastPathComponent])
    }

    func testListBackupsReturnsEmptyWhenNoneExist() throws {
        let backupsDir = try makeTempDirectory()
        XCTAssertEqual(BackupService.listBackups(in: backupsDir), [])
    }
}
