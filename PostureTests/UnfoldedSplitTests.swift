import XCTest
@testable import Posture

/// The unfolded iPhone Duo split: Today left of the fold, History right of it.
final class UnfoldedSplitTests: XCTestCase {
    /// The unfolded inner display, held landscape, and its measured fold.
    private let innerWidth: CGFloat = 951
    private let fold: ClosedRange<CGFloat> = 455.5...495.5

    func testCompactWidthKeepsOneColumn() {
        // The folded outer display, and any compact width with a fold reported.
        XCTAssertNil(UnfoldedSplit.make(width: 466, isRegularWidth: false, fold: nil))
        XCTAssertNil(UnfoldedSplit.make(width: innerWidth, isRegularWidth: false, fold: fold))
    }

    func testRegularWidthTooNarrowForTwoPanesKeepsOneColumn() {
        // The unfolded Duo held in portrait.
        XCTAssertNil(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil))
        XCTAssertNil(UnfoldedSplit.make(width: 719, isRegularWidth: true, fold: nil))
    }

    func testPanesSitAtTheFoldEdges() {
        let split = UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: fold)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 455.5, secondaryX: 495.5, secondaryWidth: 455.5))
    }

    func testZeroWidthFoldStillMeetsIt() {
        let split = UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 475...475)
        XCTAssertEqual(split?.primaryWidth, 475)
        XCTAssertEqual(split?.secondaryX, 475)
        XCTAssertEqual(split.map { $0.primaryWidth + $0.secondaryWidth }, innerWidth)
    }

    func testNoFoldSplitsEvenly() {
        let split = UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: nil)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    func testOffCentreFoldFallsBackToAnEvenSplit() {
        // Meeting this fold would leave the trailing pane under 360 pt.
        let split = UnfoldedSplit.make(width: 800, isRegularWidth: true, fold: 500...510)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 400, secondaryX: 400, secondaryWidth: 400))
    }

    func testEverySplitKeepsBothPanesUsableAndCoversTheWidth() {
        for width in stride(from: CGFloat(600), through: 1400, by: 7) {
            guard let split = UnfoldedSplit.make(width: width, isRegularWidth: true, fold: nil) else {
                XCTAssertLessThan(width, UnfoldedSplit.minimumPaneWidth * 2)
                continue
            }
            XCTAssertGreaterThanOrEqual(split.primaryWidth, UnfoldedSplit.minimumPaneWidth)
            XCTAssertGreaterThanOrEqual(split.secondaryWidth, UnfoldedSplit.minimumPaneWidth)
            XCTAssertEqual(split.secondaryX + split.secondaryWidth, width)
        }
    }
}

/// Where a split pane's content stops above its floating tab bar.
final class PaneCutTests: XCTestCase {
    func testFoldedKeepsThePhoneLayout() {
        XCTAssertEqual(TabBarClearance.make(isSplit: false, barInset: 81), TabBarClearance(hidden: 0, contentPadding: 0))
    }

    func testSplitHidesEverythingUnderTheBar() {
        let clearance = TabBarClearance.make(isSplit: true, barInset: 81)
        // Content is gone a gap above the bar's top edge, and the last row can
        // scroll all the way up to that line, so it is never cut.
        XCTAssertEqual(clearance.hidden, 81 + TabBarClearance.gap)
        XCTAssertEqual(clearance.contentPadding, TabBarClearance.gap)
    }

    func testNegativeInsetNeverUncoversTheBar() {
        XCTAssertEqual(TabBarClearance.make(isSplit: true, barInset: -4).hidden, TabBarClearance.gap)
    }

    // The line sits at 574 in each case.

    func testRowsClearOfTheLineCutAtTheLine() {
        let rows = [PaneCut.Row(minY: 100, maxY: 300, card: nil),
                    PaneCut.Row(minY: 316, maxY: 574, card: nil),
                    PaneCut.Row(minY: 590, maxY: 700, card: nil)]
        XCTAssertEqual(PaneCut.make(line: 574, rows: rows), PaneCut(y: 574, card: nil))
    }

    func testASlicedCardIsHiddenWhole() {
        // Today's badge strip under the practice card.
        let rows = [PaneCut.Row(minY: 240, maxY: 520, card: nil),
                    PaneCut.Row(minY: 540, maxY: 596, card: nil)]
        XCTAssertEqual(PaneCut.make(line: 574, rows: rows), PaneCut(y: 540 - PaneCut.margin, card: nil))
    }

    func testASlicedFormRowClosesItsSectionAboveTheSeparator() {
        let rows = [PaneCut.Row(minY: 360, maxY: 494, card: .groupedList),
                    PaneCut.Row(minY: 494, maxY: 630, card: .groupedList)]
        XCTAssertEqual(PaneCut.make(line: 574, rows: rows), PaneCut(y: 494 - PaneCut.margin, card: .groupedList))
    }

    func testAHeaderGoesWithItsFirstRow() {
        // The header's frame is stretched by its keep-with-next allowance.
        let rows = [PaneCut.Row(minY: 540, maxY: 560 + 56, card: nil),
                    PaneCut.Row(minY: 568, maxY: 620, card: nil)]
        XCTAssertEqual(PaneCut.make(line: 574, rows: rows), PaneCut(y: 540 - PaneCut.margin, card: nil))
    }

    func testATallRowIsSlicedRatherThanEmptyThePane() {
        let rows = [PaneCut.Row(minY: 574 - PaneCut.maxLift - 1, maxY: 900, card: nil)]
        XCTAssertEqual(PaneCut.make(line: 574, rows: rows), PaneCut(y: 574, card: nil))
    }
}
