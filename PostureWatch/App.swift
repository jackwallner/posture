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
    }
}
