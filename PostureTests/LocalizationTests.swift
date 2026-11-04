import XCTest
@testable import Posture

/// The string catalog compiles into en.lproj, and its plural and substitution
/// values keep the English wording. A key that fell through would still pass a
/// "not empty" check, so these compare against the visible copy.
final class LocalizationTests: XCTestCase {
    private func bundle() throws -> Bundle {
        let hosts = [Bundle.main] + Bundle.allBundles
        for host in hosts {
            if let path = host.path(forResource: "en", ofType: "lproj"),
               FileManager.default.fileExists(atPath: path + "/Localizable.strings"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return try XCTUnwrap(nil as Bundle?, "en.lproj/Localizable.strings is missing")
    }

    func testPluralsKeepEnglishWording() throws {
        let en = try bundle()
        XCTAssertEqual(String(localized: "\(1) minutes", bundle: en), "1 minute")
        XCTAssertEqual(String(localized: "\(3) minutes", bundle: en), "3 minutes")
        XCTAssertEqual(String(localized: "\(1) days", bundle: en), "1 day")
        XCTAssertEqual(String(localized: "\(0) days", bundle: en), "0 days")
        XCTAssertEqual(String(localized: "\(1) saves ready", bundle: en), "1 save ready")
        XCTAssertEqual(String(localized: "\(2) slouches caught", bundle: en), "2 slouches caught")
        XCTAssertEqual(String(localized: "\(1) slouches caught", bundle: en), "1 slouch caught")
        XCTAssertEqual(String(localized: "\(1) minutes held tall", bundle: en), "1 minute held tall")
    }

    func testSubstitutionsKeepEnglishWording() throws {
        let en = try bundle()
        XCTAssertEqual(String(localized: "Pass \(1) more sessions to reach Level \(4)", bundle: en),
                       "Pass 1 more session to reach Level 4")
        XCTAssertEqual(String(localized: "Pass \(3) more sessions to reach Level \(4)", bundle: en),
                       "Pass 3 more sessions to reach Level 4")
        XCTAssertEqual(String(localized: "\(1) practice minutes across \(2) sessions this week", bundle: en),
                       "1 practice minute across 2 sessions this week")
        XCTAssertEqual(String(localized: "\(5) practice minutes across \(1) sessions this week", bundle: en),
                       "5 practice minutes across 1 session this week")
        XCTAssertEqual(String(localized: "\("2h 5m") monitored across \(1) days", bundle: en),
                       "2h 5m monitored across 1 day")
        XCTAssertEqual(String(localized: "Level \(3) unlocked. Next: pass \(1) more sessions to reach level \(4)", bundle: en),
                       "Level 3 unlocked. Next: pass 1 more session to reach level 4")
        XCTAssertEqual(String(localized: "\("$9.99") / \(3) months", bundle: en), "$9.99 / 3 months")
    }

    func testPercentSignsSurvive() throws {
        let en = try bundle()
        XCTAssertEqual(String(localized: "\(45)% aligned today. Your streak is safe.", bundle: en),
                       "45% aligned today. Your streak is safe.")
        XCTAssertEqual(String(localized: "Score at or above the day's aligned-% target and the session is a pass.", bundle: en),
                       "Score at or above the day's aligned-% target and the session is a pass.")
        XCTAssertEqual(String(localized: "Hold it tall for \("4:05") more. Finish and today's streak day is yours; hit the target % and you level up.", bundle: en),
                       "Hold it tall for 4:05 more. Finish and today's streak day is yours; hit the target % and you level up.")
    }

    func testPluralCategoryPicksTheLabel() {
        XCTAssertEqual(PluralLabel.category(1), .one)
        XCTAssertEqual(PluralLabel.category(5), .other)
        XCTAssertEqual(PluralLabel.days(1), "day")
        XCTAssertEqual(PluralLabel.days(12), "days")
        XCTAssertEqual(PluralLabel.savesReady(1), "save ready")
        XCTAssertEqual(PluralLabel.savesReady(2), "saves ready")
    }

    func testFormattersKeepUSEnglish() throws {
        try XCTSkipUnless(Locale.current.identifier == "en_US", "US English wording only")
        var parts = DateComponents(year: 2026, month: 11, day: 4, hour: 17, minute: 15, second: 9)
        parts.calendar = .current
        let date = try XCTUnwrap(parts.date)
        XCTAssertEqual(DisplayFormat.monthDay(date), "Nov 4")
        XCTAssertEqual(DisplayFormat.shortWeekdayMonthDay(date), "Wed, Nov 4")
        XCTAssertEqual(DisplayFormat.weekdayMonthDay(date), "Wednesday, Nov 4")
        XCTAssertEqual(DisplayFormat.narrowWeekday(date), "W")
        XCTAssertEqual(DisplayFormat.time(date), "5:15 PM")
        XCTAssertEqual(DisplayFormat.timeWithSeconds(date), "5:15:09 PM")
        XCTAssertEqual(DisplayFormat.weekdayAndTime(date), "Wednesday · 5:15 PM")
        XCTAssertEqual(DisplayFormat.hour(0), "12am")
        XCTAssertEqual(DisplayFormat.hour(9), "9am")
        XCTAssertEqual(DisplayFormat.hour(15), "3pm")
        XCTAssertEqual(DisplayFormat.hour(0, narrow: true), "12a")
        XCTAssertEqual(DisplayFormat.hour(12, narrow: true), "12p")
        XCTAssertEqual(DisplayFormat.minutesSeconds(185), "3m 5s")
        XCTAssertEqual(DisplayFormat.minutesSeconds(5), "5s")
        XCTAssertEqual(DisplayFormat.seconds(125), "125s")
        XCTAssertEqual(DisplayFormat.minutes(38), "38m")
        XCTAssertEqual(DisplayFormat.clock(245), "4:05")
        XCTAssertEqual(DisplayFormat.clock(5), "0:05")
        XCTAssertEqual(DisplayFormat.distanceValue(meters: 1500, metric: true), "1.50")
        XCTAssertEqual(DisplayFormat.distanceValue(meters: 15000, metric: true), "15.0")
        XCTAssertEqual(DisplayFormat.distanceWithUnit(meters: 1500, metric: true), "1.50 km")
        XCTAssertEqual(DisplayFormat.distanceWithUnit(2.5, metric: false, fractionDigits: 1), "2.5 mi")
    }
}
