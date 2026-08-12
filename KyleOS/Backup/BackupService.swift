import Foundation

/// A simple manual "Back Up Kyle OS" action (PRD §16.6): copies the local SwiftData store —
/// which already holds writing data, work history, calendar data, and settings as one unified
/// store — into a timestamped folder. External source video files are never copied; File
/// References only ever store bookmarks, never the media itself, so there's nothing extra to
/// exclude.
///
/// This is a file copy, not a coordinated hot-backup: call it when the app isn't actively
/// mid-write for the cleanest snapshot. A fully atomic backup would need to coordinate with the
/// open ModelContainer (e.g. a checkpoint before copying) — a refinement beyond Foundation's
/// "basic backup is possible" acceptance bar.
enum BackupService {
    enum BackupError: Error, Equatable {
        case sourceStoreNotFound
    }

    /// Matches `PersistenceController.storeDirectory` — the real store's `KyleOS/` namespaced
    /// location, not SwiftData's bare shared default (see that type's doc comment for why the
    /// namespacing matters).
    static var defaultStoreDirectory: URL {
        PersistenceController.storeDirectory
    }

    static var defaultBackupsDirectory: URL {
        defaultStoreDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    /// SwiftData's default (unnamed) ModelConfiguration always uses this base filename, plus
    /// SQLite's WAL-mode sidecar files, which may or may not exist depending on checkpoint state.
    static func storeFileURLs(in directory: URL) -> [URL] {
        ["default.store", "default.store-shm", "default.store-wal"]
            .map { directory.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    @discardableResult
    static func createBackup(
        storeDirectory: URL = defaultStoreDirectory,
        backupsDirectory: URL = defaultBackupsDirectory,
        at date: Date = .now
    ) throws -> URL {
        let storeFiles = storeFileURLs(in: storeDirectory)
        guard !storeFiles.isEmpty else { throw BackupError.sourceStoreNotFound }

        let destination = backupsDirectory.appendingPathComponent(backupFolderName(for: date), isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for fileURL in storeFiles {
            try FileManager.default.copyItem(at: fileURL, to: destination.appendingPathComponent(fileURL.lastPathComponent))
        }
        return destination
    }

    /// Restores a backup by copying its store files into `storeDirectory`, overwriting any
    /// existing store there. Callers must ensure no ModelContainer is currently open on the
    /// destination — SwiftData doesn't support hot-swapping the underlying file out from under a
    /// live container. No confirmation/relaunch UI wraps this yet (same as every other model-only
    /// step in this build brief sequence) — a future screen owns that flow.
    static func restoreBackup(from backupDirectory: URL, to storeDirectory: URL = defaultStoreDirectory) throws {
        let files = storeFileURLs(in: backupDirectory)
        guard !files.isEmpty else { throw BackupError.sourceStoreNotFound }
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        for fileURL in files {
            let target = storeDirectory.appendingPathComponent(fileURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: fileURL, to: target)
        }
    }

    static func listBackups(in backupsDirectory: URL = defaultBackupsDirectory) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } // newest first — timestamped names sort lexically
    }

    private static func backupFolderName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "Backup-\(formatter.string(from: date))"
    }
}
