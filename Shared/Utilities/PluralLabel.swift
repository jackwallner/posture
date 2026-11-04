import Foundation

/// Count labels shown beside a number that is drawn separately ("3" over
/// "saves ready"). A catalog plural variant has to contain its number, so these
/// labels cannot be plural keys themselves. Instead the catalog's
/// `"%lld plural category"` key returns the CLDR category for the user's
/// language ("few 3"), and each label has one whole key per category.
enum PluralLabel {
    enum Category: String {
        case one, few, many, other
    }

    static func category(_ count: Int) -> Category {
        let token = String(localized: "\(count) plural category")
        let word = token.split(separator: " ").first.map(String.init) ?? ""
        return Category(rawValue: word) ?? (count == 1 ? .one : .other)
    }

    /// "day" / "days", beside the streak flame's count.
    static func days(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "day")
        case .few: String(localized: "days (few)")
        case .many: String(localized: "days (many)")
        case .other: String(localized: "days")
        }
    }

    /// "save ready" / "saves ready", under the streak detail's save count.
    static func savesReady(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "save ready")
        case .few: String(localized: "saves ready (few)")
        case .many: String(localized: "saves ready (many)")
        case .other: String(localized: "saves ready")
        }
    }
}
