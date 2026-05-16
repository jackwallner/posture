import Foundation
import SwiftData
import os

let postureAppGroupID = "group.com.jackwallner.posture"

@MainActor
enum DataService {
    static let appGroupID = postureAppGroupID

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PostureSession.self,
            PosturePassiveSample.self,
            Calibration.self,
            StreakState.self,
            BeforeAfterPhoto.self,
            AcknowledgmentRecord.self,
        ])
        let url = containerURL

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Corrupt store — wipe and retry
        let storeFiles = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
        for file in storeFiles {
            try? FileManager.default.removeItem(at: file)
        }
        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Last-resort in-memory fallback so the app still launches
        let inMemory = ModelConfiguration("Posture", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            let logger = Logger(subsystem: "com.jackwallner.posture", category: "DataService")
            logger.critical("ModelContainer failed even in-memory: \(String(describing: error), privacy: .public)")
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }()

    private static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            "Posture",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static var containerURL: URL {
        let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Posture.store")
    }
}
