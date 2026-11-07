import SwiftData
import SwiftUI

@main
struct PostureWatchApp: App {
    var body: some Scene {
        WindowGroup {
            StorageContainerView {
                WatchTodayView()
            }
        }
        // The phone's streak and score arrive while the app is closed; take
        // them then so the complication is current without opening the app.
        .backgroundTask(.watchConnectivity) {
            await WatchSyncService.shared.waitForPendingContent()
        }
    }
}
