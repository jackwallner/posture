import CoreData
import Foundation
import SQLite3
import SwiftData
import os

let postureAppGroupID = "group.com.jackwallner.posture"

@MainActor
enum DataService {
    static let appGroupID = postureAppGroupID

    @MainActor
    final class RecoveryState {
        fileprivate(set) var attempted = false
    }

    private static let launchRecovery = RecoveryState()
    private static let logger = Logger(subsystem: "com.jackwallner.posture", category: "DataService")

    private(set) static var containerResult = Result { try openContainer(at: containerURL) }

    /// Only access after StorageContainerView has opened the disk store.
    static var sharedModelContainer: ModelContainer {
        guard case .success(let container) = containerResult else {
            preconditionFailure("The persistent store is unavailable")
        }
        return container
    }

    static func retry() {
        containerResult = Result { try openContainer(at: containerURL) }
    }

    static func openContainer(
        at url: URL,
        recovery: RecoveryState = launchRecovery,
        makeContainer: @MainActor (Schema, URL) throws -> ModelContainer = makeContainer
    ) throws -> ModelContainer {
        let schema = Schema([
            PostureSession.self,
            PosturePassiveSample.self,
            PostureMinuteSample.self,
            Calibration.self,
            StreakState.self,
            BeforeAfterPhoto.self,
            AcknowledgmentRecord.self,
        ])

        do {
            return try makeContainer(schema, url)
        } catch {
            guard isTransient(error) else {
                return try recoverContainer(at: url, schema: schema, error: error,
                                            recovery: recovery, makeContainer: makeContainer)
            }
            logger.error("Persistent store open failed, retrying without changing files: \(String(describing: error), privacy: .public)")
        }
        // File-access failures leave history in place. Other failures preserve
        // the store and its sidecars in a backup before one fresh open per launch.
        do {
            return try makeContainer(schema, url)
        } catch {
            return try recoverContainer(at: url, schema: schema, error: error,
                                        recovery: recovery, makeContainer: makeContainer)
        }
    }

    private static func isTransient(_ error: Error) -> Bool {
        var pending = [error as NSError]
        var visited = Set<ObjectIdentifier>()
        while let error = pending.popLast() {
            guard visited.insert(ObjectIdentifier(error)).inserted else { continue }
            if error.domain == NSPOSIXErrorDomain { return true }
            if error.domain == NSCocoaErrorDomain,
               (NSFileErrorMinimum...NSFileErrorMaximum).contains(error.code) { return true }
            if error.domain == NSSQLiteErrorDomain {
                // Extended SQLite codes keep the primary code in the low byte.
                switch Int32(error.code & 0xff) {
                case SQLITE_PERM, SQLITE_BUSY, SQLITE_LOCKED, SQLITE_READONLY,
                     SQLITE_IOERR, SQLITE_FULL, SQLITE_CANTOPEN, SQLITE_AUTH:
                    return true
                default:
                    break
                }
            }
            pending.append(contentsOf: error.underlyingErrors.map { $0 as NSError })
            pending.append(contentsOf: error.userInfo[NSDetailedErrorsKey] as? [NSError] ?? [])
        }
        return false
    }

    private static func recoverContainer(
        at url: URL,
        schema: Schema,
        error: Error,
        recovery: RecoveryState,
        makeContainer: @MainActor (Schema, URL) throws -> ModelContainer
    ) throws -> ModelContainer {
        guard !isTransient(error), !recovery.attempted else { throw error }
        recovery.attempted = true
        logger.error("Persistent store needs recovery: \(String(describing: error), privacy: .public)")
        let backup = try backUpStore(at: url)
        logger.error("Preserved persistent store at \(backup.path, privacy: .public), opening a fresh store")
        return try makeContainer(schema, url)
    }

    private static func backUpStore(at url: URL) throws -> URL {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let date = ISO8601DateFormatter().string(from: .now)
        let backup = directory.appendingPathComponent("\(name) Backup \(date) \(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: backup, withIntermediateDirectories: false)
        let files = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm"),
            directory.appendingPathComponent(".\(name)_SUPPORT"),
            URL(fileURLWithPath: url.path + "_SUPPORT"),
        ]
        var moved: [URL] = []
        do {
            for file in files {
                // A throwing lookup keeps permission errors from looking like missing files.
                do {
                    _ = try manager.attributesOfItem(atPath: file.path)
                } catch {
                    let error = error as NSError
                    if error.domain == NSCocoaErrorDomain,
                       [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { continue }
                    throw error
                }
                try manager.moveItem(at: file, to: backup.appendingPathComponent(file.lastPathComponent))
                moved.append(file)
            }
        } catch {
            for file in moved.reversed() {
                do {
                    try manager.moveItem(at: backup.appendingPathComponent(file.lastPathComponent), to: file)
                } catch {
                    logger.error("Store backup rollback failed, file remains in \(backup.path, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
            throw error
        }
        return backup
    }

    private static func makeContainer(schema: Schema, url: URL) throws -> ModelContainer {
        #if DEBUG
        if LaunchArguments.contains("UITEST_STORAGE_FAILURE") {
            throw CocoaError(.fileReadNoPermission)
        }
        #endif
        let config = ModelConfiguration(
            "Posture",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static var containerURL: URL {
        get throws {
            let base = try FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            ) ?? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return base.appendingPathComponent("Posture.store")
        }
    }
}
