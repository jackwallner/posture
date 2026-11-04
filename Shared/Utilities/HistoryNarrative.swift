import Foundation

/// Generates the one-sentence story above the History week strip.
/// Deterministic - picks from a small template set based on which day
/// scored best/worst and how much data exists.
enum HistoryNarrative {
    private static func score(_ q: PostureQuality) -> Int {
        switch q {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }

    /// `acks` should already be scoped to the most-recent 7 days.
    static func sentence(for acks: [AcknowledgmentRecord], now: Date = .now) -> String {
        let cal = Calendar.current
        let scored = acks.filter { $0.quality != nil }

        // Group scored acks by day.
        let byDay = Dictionary(grouping: scored) { cal.startOfDay(for: $0.timestamp) }
        guard byDay.count >= 4 else { return String(localized: "We need a few more days.") }

        func mean(_ list: [AcknowledgmentRecord]) -> Double {
            let s = list.compactMap { $0.quality.map(score) }
            return s.isEmpty ? 0 : Double(s.reduce(0, +)) / Double(s.count)
        }

        let ranked = byDay.sorted { mean($0.value) > mean($1.value) }
        guard let best = ranked.first else { return String(localized: "We need a few more days.") }

        let bestDay = DisplayFormat.weekday(best.key)

        // Which half of the day did the best day's check-ins cluster in?
        let morningCount = best.value.filter { cal.component(.hour, from: $0.timestamp) < 13 }.count
        var sentence = morningCount >= best.value.count - morningCount
            ? String(localized: "Your best stretch was \(bestDay) morning.")
            : String(localized: "Your best stretch was \(bestDay) afternoon.")

        if let worst = ranked.last, worst.key != best.key, mean(worst.value) < Double(score(.borderline)) {
            let worstDay = DisplayFormat.weekday(worst.key)
            let wMorning = worst.value.filter { cal.component(.hour, from: $0.timestamp) < 13 }.count
            let slipped = wMorning >= worst.value.count - wMorning
                ? String(localized: "\(worstDay) morning slipped.")
                : String(localized: "\(worstDay) afternoon slipped.")
            sentence = String(localized: "\(sentence) \(slipped)")
        }
        return sentence
    }
}
