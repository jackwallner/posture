import Foundation

/// Locale-aware rendering of dates, durations and distances. In US English the
/// output matches the app's wording ("Nov 4", "9am", "1h 5m", "1.50 km"); other
/// locales get their own forms from Foundation.
enum DisplayFormat {
    // MARK: - Dates

    private static func date(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date).replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// "Nov 4"
    static func monthDay(_ value: Date) -> String { date(value, template: "MMMd") }
    /// "Wed, Nov 4"
    static func shortWeekdayMonthDay(_ value: Date) -> String { date(value, template: "EEEMMMd") }
    /// "Wednesday, Nov 4"
    static func weekdayMonthDay(_ value: Date) -> String { date(value, template: "EEEEMMMd") }
    /// "Wednesday"
    static func weekday(_ value: Date) -> String { date(value, template: "EEEE") }
    /// "W"
    static func narrowWeekday(_ value: Date) -> String { date(value, template: "EEEEE") }
    /// "5:15 PM"
    static func time(_ value: Date) -> String { date(value, template: "jmm") }
    /// "5:15:09 PM"
    static func timeWithSeconds(_ value: Date) -> String { date(value, template: "jmmss") }

    /// "Wednesday · 5:15 PM"
    static func weekdayAndTime(_ value: Date) -> String {
        String(localized: "\(weekday(value)) · \(time(value))")
    }

    /// "9am", or "9a" when narrow, on an English 12-hour clock. Everywhere else
    /// it is the locale's own hour form.
    static func hour(_ hour: Int, narrow: Bool = false) -> String {
        let components = DateComponents(year: 2024, month: 1, day: 1, hour: hour)
        let value = Calendar.current.date(from: components) ?? .now
        let text = date(value, template: "j")
        guard Locale.current.language.languageCode == .english else { return text }
        let compact = text.lowercased().filter { !$0.isWhitespace }
        guard compact.hasSuffix("am") || compact.hasSuffix("pm") else { return text }
        return narrow ? String(compact.dropLast()) : compact
    }

    // MARK: - Durations

    private static func abbreviated(seconds: Int, units: NSCalendar.Unit) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = units
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }

    /// "4h 20m", "38m", "0m"
    static func hoursMinutes(_ seconds: Int) -> String { abbreviated(seconds: seconds, units: [.hour, .minute]) }
    /// "3m 5s", "5s"
    static func minutesSeconds(_ seconds: Int) -> String { abbreviated(seconds: seconds, units: [.minute, .second]) }
    /// "38m"
    static func minutes(_ minutes: Int) -> String { abbreviated(seconds: minutes * 60, units: [.minute]) }
    /// "125s"
    static func seconds(_ seconds: Int) -> String { abbreviated(seconds: seconds, units: [.second]) }

    /// "4:05"
    static func clock(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    // MARK: - Distances

    private static func displayValue(meters: Double, metric: Bool) -> Double {
        metric ? meters / 1000 : meters / 1609.34
    }

    /// A walk distance reads 2 decimals under 10 of the unit, 1 above.
    private static func walkFractionDigits(_ value: Double) -> Int { value < 10 ? 2 : 1 }

    /// "1.50", in kilometers or miles.
    static func distanceValue(meters: Double, metric: Bool) -> String {
        let value = displayValue(meters: meters, metric: metric)
        return value.formatted(.number.precision(.fractionLength(walkFractionDigits(value))).grouping(.never))
    }

    /// "1.50 km"
    static func distanceWithUnit(meters: Double, metric: Bool) -> String {
        let value = displayValue(meters: meters, metric: metric)
        return distanceWithUnit(value, metric: metric, fractionDigits: walkFractionDigits(value))
    }

    /// "1.5 mi", from a value already in the user's unit.
    static func distanceWithUnit(_ value: Double, metric: Bool, fractionDigits: Int) -> String {
        let number = NumberFormatter()
        number.numberStyle = .decimal
        number.usesGroupingSeparator = false
        number.minimumFractionDigits = fractionDigits
        number.maximumFractionDigits = fractionDigits
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter = number
        return formatter.string(from: Measurement(value: value, unit: metric ? UnitLength.kilometers : UnitLength.miles))
    }
}
