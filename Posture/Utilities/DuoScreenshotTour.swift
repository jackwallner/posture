#if DEBUG
import Foundation

/// Unattended iPhone Duo capture (`gh-sim launch --device 'iPhone Duo'`).
/// DEBUG only, so none of it ships.
///
/// `-DuoTour` walks the main screens on a timer, because `simctl openurl`
/// raises a confirmation alert and the capture job cannot tap. `-DuoRoutes a,b`
/// is the walk while folded and `-DuoRoutesRegular a,b` while split (the inner
/// display). `-DuoTourFirst <s>` is the delay before the first route and
/// `-DuoTourStep <s>` the dwell on each. The walk runs once and holds its last
/// route, which is what gh-sim's single screenshot per display captures; it
/// restarts when the panes split or join, so each display gets all of it.
/// Every step is logged as a `DUOTOUR` line, which maps the captures to routes.
///
/// Routes: today, history, progress, settings, and session (the latest
/// session's detail; while split it opens in the History pane and leaves the
/// leading tab as it is).
enum DuoScreenshotTour {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isEnabled: Bool { arguments.contains("-DuoTour") }

    static func routes(split: Bool) -> [String] {
        let list = value(split ? "-DuoRoutesRegular" : "-DuoRoutes")
            ?? (split ? "today,progress,session,settings" : "today,history,progress,settings")
        return list.split(separator: ",").map(String.init)
    }

    static var firstDelay: Double { value("-DuoTourFirst").flatMap(Double.init) ?? 2 }
    static var step: Double { value("-DuoTourStep").flatMap(Double.init) ?? 10 }

    private static func value(_ key: String) -> String? {
        // The last one wins, so a gh-sim `--screen` can override `--args`.
        guard let i = arguments.lastIndex(of: key), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }
}

extension Notification.Name {
    /// The tour asks History to open its newest session, or to close it.
    static let postureDebugOpenLatestSession = Notification.Name("com.jackwallner.posture.debug.openLatestSession")
    static let postureDebugCloseSession = Notification.Name("com.jackwallner.posture.debug.closeSession")
}
#endif
