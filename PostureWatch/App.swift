import SwiftData
import SwiftUI

@main
struct PostureWatchApp: App {
    init() {
        // Here, not in a view: a workout launch can run the app before any
        // view appears, and an iPhone relay must still reach the haptic.
        WatchSyncService.shared.onSlouchNudge = { WatchSlouchHaptic.playRelayed(sentAt: $0) }
        WatchSyncService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            StorageContainerView {
                WatchTodayView()
            }
        }
    }
}
