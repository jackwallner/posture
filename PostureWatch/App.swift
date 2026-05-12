import SwiftData
import SwiftUI

@main
struct PostureWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchTodayView()
        }
        .modelContainer(DataService.sharedModelContainer)
    }
}
