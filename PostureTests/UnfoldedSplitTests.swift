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
