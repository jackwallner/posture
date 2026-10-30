import XCTest
@testable import Posture

/// The string catalog compiles into one .lproj per language, and the plural
/// rules survive the trip. A key that fell back to English would still pass a
/// "not empty" check, so these compare against the catalog's own wording.
final class LocalizationTests: XCTestCase {
    static let languages = ["de", "es", "fr", "it", "ja", "nl", "pl", "pt-BR"]

    private func bundle(_ language: String) -> Bundle? {
        let hosts = [Bundle.main, Bundle(for: LocalizationTests.self)] + Bundle.allBundles
        for host in hosts {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    func testEveryLanguageShips() {
        for language in Self.languages {
            XCTAssertNotNil(bundle(language), "\(language).lproj is missing")
        }
    }

    func testPolishPluralsPickTheRightForm() throws {
        let pl = try XCTUnwrap(bundle("pl"))
        let locale = Locale(identifier: "pl")
        XCTAssertEqual(String(localized: "\(1) saves ready", bundle: pl, locale: locale), "1 osłona gotowa")
        XCTAssertEqual(String(localized: "\(3) saves ready", bundle: pl, locale: locale), "3 osłony gotowe")
        XCTAssertEqual(String(localized: "\(5) saves ready", bundle: pl, locale: locale), "5 osłon gotowych")
    }

    func testSubstitutionPluralKeepsTheOtherArgument() throws {
        let de = try XCTUnwrap(bundle("de"))
        let locale = Locale(identifier: "de")
        XCTAssertEqual(
            String(localized: "Pass \(1) more sessions to reach Level \(4)", bundle: de, locale: locale),
            "Bestehe noch 1 Einheit bis Level 4"
        )
        XCTAssertEqual(
            String(localized: "Pass \(2) more sessions to reach Level \(4)", bundle: de, locale: locale),
            "Bestehe noch 2 Einheiten bis Level 4"
        )
    }

    func testCopyIsTranslated() throws {
        let de = try XCTUnwrap(bundle("de"))
        XCTAssertEqual(String(localized: "Begin today's practice", bundle: de), "Heutige Übung starten")
        let ja = try XCTUnwrap(bundle("ja"))
        XCTAssertEqual(
            String(localized: "\(3)-day streak", bundle: ja, locale: Locale(identifier: "ja")),
            "3日連続"
        )
    }

    func testEnglishPluralsReadNaturally() {
        XCTAssertEqual(String(localized: "\(1) saves ready", locale: Locale(identifier: "en")), "1 save ready")
        XCTAssertEqual(String(localized: "\(2) saves ready", locale: Locale(identifier: "en")), "2 saves ready")
    }
}
