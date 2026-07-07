import Foundation

enum LaunchArguments {
    static func contains(_ name: String) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(name) || arguments.contains("-\(name)")
    }
}

enum AppClock {
    static var now: Date {
        #if DEBUG
        if let override = debugOverrideDate() { return override }
        #endif
        return Date()
    }

    #if DEBUG
    /// Keeps screenshot copy aligned with `simctl status_bar --time` runs.
    /// Use `-AppClockTime 9:41`; screenshot seeds default to the App Store
    /// screenshot time because the status-bar override is display-only.
    private static func debugOverrideDate() -> Date? {
        let arguments = ProcessInfo.processInfo.arguments
        let time = argumentValue(after: "-AppClockTime", in: arguments)
            ?? argumentValue(after: "AppClockTime", in: arguments)
            ?? (LaunchArguments.contains("SCREENSHOT_SEED") ? "9:41" : nil)
        guard let time else { return nil }

        let parts = time.split(separator: ":", maxSplits: 1).compactMap { Int($0) }
        guard parts.count == 2,
              (0...23).contains(parts[0]),
              (0...59).contains(parts[1])
        else { return nil }

        return Calendar.current.date(
            bySettingHour: parts[0],
            minute: parts[1],
            second: 0,
            of: Date()
        )
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    #endif
}
