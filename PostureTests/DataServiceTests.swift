import CoreData
import Foundation
import SwiftData
import XCTest

@MainActor
final class DataServiceTests: XCTestCase {
    func testCorruptStoreIsPreservedAndReportsFailure() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        let history = Data("damaged but potentially recoverable history".utf8)
        try history.write(to: url)

        XCTAssertThrowsError(try DataService.openContainer(at: url))
        XCTAssertEqual(try Data(contentsOf: url), history)
    }

    func testUnavailableStoreIsPreservedAndReportsFailure() throws {
        try assertPreserved(after: NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError))
    }

    func testFullDiskPreservesStoreAndReportsFailure() throws {
        try assertPreserved(after: NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError))
    }

    func testIncompatibleModelPreservesStoreAndReportsFailure() throws {
        try assertPreserved(after: NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError))
    }

    func testUnknownErrorPreservesStoreAndReportsFailure() throws {
        try assertPreserved(after: NSError(domain: "UnexpectedStoreError", code: 1))
    }

    func testUnwritableLocationDoesNotFallBackToMemory() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let blocker = directory.appendingPathComponent("not-a-directory")
        let contents = Data("keep this file".utf8)
        try contents.write(to: blocker)

        XCTAssertThrowsError(try DataService.openContainer(at: blocker.appendingPathComponent("Posture.store")))
        XCTAssertEqual(try Data(contentsOf: blocker), contents)
    }

    func testRetryReopensExistingHistoryAfterTransientFailure() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        var attempts = 0
        do {
            let container = try DataService.openContainer(at: url)
            container.mainContext.insert(StreakState(currentStreak: 7, longestStreak: 12))
            try container.mainContext.save()
        }

        let container = try DataService.openContainer(at: url) { schema, storeURL in
            attempts += 1
            if attempts == 1 {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
            }
            return try ModelContainer(for: schema, configurations: [
                ModelConfiguration("Posture", schema: schema, url: storeURL, cloudKitDatabase: .none),
            ])
        }

        XCTAssertEqual(attempts, 2)
        XCTAssertFalse(container.configurations.first!.isStoredInMemoryOnly)
        let streak = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<StreakState>()).first)
        XCTAssertEqual(streak.currentStreak, 7)
        XCTAssertEqual(streak.longestStreak, 12)
    }

    private func assertPreserved(after error: NSError) throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Posture.store")
        // Include SQLite's real sidecar names and the names used by the old reset.
        let files = [url, URL(fileURLWithPath: url.path + "-wal"), URL(fileURLWithPath: url.path + "-shm"),
                     url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
        for file in files {
            try Data(file.lastPathComponent.utf8).write(to: file)
        }
        var attempts = 0

        XCTAssertThrowsError(try DataService.openContainer(at: url) { _, _ in
            attempts += 1
            for file in files {
                XCTAssertEqual(try Data(contentsOf: file), Data(file.lastPathComponent.utf8))
            }
            throw error
        }) { thrown in
            XCTAssertEqual(thrown as NSError, error)
        }

        XCTAssertEqual(attempts, 2)
        for file in files {
            XCTAssertEqual(try Data(contentsOf: file), Data(file.lastPathComponent.utf8))
        }
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
