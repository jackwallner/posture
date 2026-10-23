import Foundation
import SwiftData
import os

let postureAppGroupID = "group.com.jackwallner.posture"

@MainActor
enum DataService {
    static let appGroupID = postureAppGroupID

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
            let logger = Logger(subsystem: "com.jackwallner.posture", category: "DataService")
            logger.error("Persistent store open failed, retrying without changing files: \(String(describing: error), privacy: .public)")
        }
        // Even confirmed corruption may contain recoverable history. Never
        // delete the store or its sidecars, and never substitute an empty store.
        return try makeContainer(schema, url)
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
