import CoreData
import Foundation
import SQLite3
import SwiftData
import XCTest

@MainActor
final class DataServiceTests: XCTestCase {
    func testCorruptStoreIsBackedUpAndReplacedWithWorkingContainer() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        let history = Data("damaged but potentially recoverable history".utf8)
        try history.write(to: url)

        let container = try DataService.openContainer(at: url, recovery: .init())

        let backup = try onlyBackup(in: directory)
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("Posture.store")), history)
        try assertWorking(container)
    }

    func testTransientErrorsPreserveAllFilesAndReportFailure() throws {
        let errors = [
            CocoaError(.fileReadNoPermission) as NSError,
            CocoaError(.fileWriteNoPermission) as NSError,
            CocoaError(.fileWriteOutOfSpace) as NSError,
            CocoaError(.fileReadUnknown) as NSError,
            CocoaError(.fileLocking) as NSError,
            CocoaError(.fileReadCorruptFile) as NSError,
            NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)),
            NSError(domain: NSSQLiteErrorDomain, code: Int(SQLITE_PERM)),
            NSError(domain: NSSQLiteErrorDomain, code: Int(SQLITE_FULL)),
            NSError(domain: NSSQLiteErrorDomain, code: Int(SQLITE_IOERR) | (1 << 8)),
            NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreOpenError, userInfo: [
                NSUnderlyingErrorKey: CocoaError(.fileReadNoPermission),
            ]),
            NSError(domain: NSCocoaErrorDomain, code: NSMigrationError, userInfo: [
                NSMultipleUnderlyingErrorsKey: [NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))],
            ]),
            NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreOpenError, userInfo: [
                NSDetailedErrorsKey: [CocoaError(.fileWriteOutOfSpace)],
            ]),
        ]
        for error in errors {
            try assertPreserved(after: error)
        }
    }

    func testUnrecoverableErrorsBackUpAllFilesAndReturnWorkingContainer() throws {
        let errors = [
            NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError),
            NSError(domain: NSCocoaErrorDomain, code: NSMigrationError),
            NSError(domain: NSSQLiteErrorDomain, code: Int(SQLITE_CORRUPT)),
            NSError(domain: "UnexpectedStoreError", code: 1),
        ]
        for error in errors {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("Posture.store")
            let files = try seedFiles(at: url)
            var attempts = 0

            let container = try DataService.openContainer(at: url, recovery: .init()) { schema, storeURL in
                attempts += 1
                if attempts == 1 { throw error }
                let backup = try self.onlyBackup(in: directory)
                try self.assertFiles(files, in: backup)
                for name in files.keys {
                    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path))
                }
                return try self.makeContainer(schema: schema, url: storeURL)
            }

            XCTAssertEqual(attempts, 2)
            try assertWorking(container)
            try assertFiles(files, in: onlyBackup(in: directory))
        }
    }

    func testFreshOpenFailureThrowsAndRetryDoesNotBackUpAgain() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        let files = try seedFiles(at: url)
        let recovery = DataService.RecoveryState()
        let initial = NSError(domain: NSCocoaErrorDomain, code: NSMigrationError)
        let fresh = NSError(domain: "FreshStoreError", code: 2)
        let freshContents = Data("keep the failed fresh store too".utf8)
        var attempts = 0

        XCTAssertThrowsError(try DataService.openContainer(at: url, recovery: recovery) { _, _ in
            attempts += 1
            if attempts == 1 { throw initial }
            try freshContents.write(to: url)
            throw fresh
        }) { XCTAssertEqual($0 as NSError, fresh) }
        XCTAssertEqual(attempts, 2)
        try assertFiles(files, in: onlyBackup(in: directory))

        XCTAssertThrowsError(try DataService.openContainer(at: url, recovery: recovery) { _, _ in
            attempts += 1
            throw initial
        }) { XCTAssertEqual($0 as NSError, initial) }
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(try Data(contentsOf: url), freshContents)
        try assertFiles(files, in: onlyBackup(in: directory))
    }

    func testUnwritableLocationDoesNotFallBackToMemory() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let blocker = directory.appendingPathComponent("not-a-directory")
        let contents = Data("keep this file".utf8)
        try contents.write(to: blocker)

        XCTAssertThrowsError(try DataService.openContainer(at: blocker.appendingPathComponent("Posture.store"), recovery: .init()))
        XCTAssertEqual(try Data(contentsOf: blocker), contents)
    }

    func testRetryReopensExistingHistoryAfterTransientFailure() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        let recovery = DataService.RecoveryState()
        var attempts = 0
        do {
            let container = try DataService.openContainer(at: url, recovery: recovery)
            container.mainContext.insert(StreakState(currentStreak: 7, longestStreak: 12))
            try container.mainContext.save()
        }

        let container = try DataService.openContainer(at: url, recovery: recovery) { schema, storeURL in
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileReadNoPermission) }
            return try self.makeContainer(schema: schema, url: storeURL)
        }

        XCTAssertEqual(attempts, 2)
        XCTAssertFalse(container.configurations.first!.isStoredInMemoryOnly)
        let streak = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<StreakState>()).first)
        XCTAssertEqual(streak.currentStreak, 7)
        XCTAssertEqual(streak.longestStreak, 12)
        XCTAssertFalse(recovery.attempted)
    }

    private func assertPreserved(after error: NSError) throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        let files = try seedFiles(at: url)
        let recovery = DataService.RecoveryState()
        var attempts = 0

        XCTAssertThrowsError(try DataService.openContainer(at: url, recovery: recovery) { _, _ in
            attempts += 1
            try self.assertFiles(files, in: directory)
            throw error
        }) { XCTAssertEqual($0 as NSError, error) }

        XCTAssertEqual(attempts, 2)
        try assertFiles(files, in: directory)
        XCTAssertFalse(recovery.attempted)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix("Posture Backup ") })
    }

    private func seedFiles(at url: URL) throws -> [String: Data] {
        let files = ["Posture.store", "Posture.store-wal", "Posture.store-shm",
                     ".Posture_SUPPORT/_EXTERNAL_DATA/history", "Posture.store_SUPPORT/history"]
        for name in files {
            let file = url.deletingLastPathComponent().appendingPathComponent(name)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(name.utf8).write(to: file)
        }
        return Dictionary(uniqueKeysWithValues: files.map { ($0, Data($0.utf8)) })
    }

    private func assertFiles(_ files: [String: Data], in directory: URL) throws {
        for (name, data) in files {
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(name)), data)
        }
    }

    private func onlyBackup(in directory: URL) throws -> URL {
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("Posture Backup ") }
        XCTAssertEqual(backups.count, 1)
        return try XCTUnwrap(backups.first)
    }

    private func makeContainer(schema: Schema, url: URL) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Posture", schema: schema, url: url, cloudKitDatabase: .none),
        ])
    }

    private func assertWorking(_ container: ModelContainer) throws {
        XCTAssertFalse(container.configurations.first!.isStoredInMemoryOnly)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<StreakState>()).isEmpty)
        container.mainContext.insert(StreakState(currentStreak: 1, longestStreak: 1))
        try container.mainContext.save()
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<StreakState>()).count, 1)
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
