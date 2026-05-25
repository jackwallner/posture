import Foundation

/// App Store review deep links for Posture.
enum AppStoreReviewLinks {
    static let appStoreID = "6768514450"

    /// Opens the App Store write-review page (explicit user-initiated rating CTAs only).
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
