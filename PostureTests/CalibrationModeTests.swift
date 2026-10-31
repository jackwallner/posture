import XCTest
@testable import Posture

/// How the calibration flow's last screen leaves. First-run setup hands off by
/// flipping `hasCalibrated`, which swaps the root view to the tabs. Every
/// recalibrate runs in a sheet over Settings or Today, so its last button has to
/// dismiss that sheet: setting a flag that is already true changes nothing.
@MainActor
final class CalibrationModeTests: XCTestCase {
    func testFirstRunSetupHandsOffThroughTheFlag() {
        XCTAssertFalse(CalibrationView.Mode.onboarding.dismissesWhenDone)
    }

    func testEveryRecalibrateDismissesItsSheet() {
        XCTAssertTrue(CalibrationView.Mode.quickRecalibrate.dismissesWhenDone)
        XCTAssertTrue(CalibrationView.Mode.recalibrateStanding.dismissesWhenDone)
        XCTAssertTrue(CalibrationView.Mode.recalibrateSitting.dismissesWhenDone)
    }
}
