import XCTest
@testable import Posture

#if DEBUG
/// The simulated-AirPods stub reports a connect from inside start(). The
/// background monitor answers every connect by calling start() again, so the
/// stub must already count as running by then or the two recurse forever.
@MainActor
final class HeadphoneMotionStubTests: XCTestCase {
    func testStartFromConnectCallbackDoesNotRecurse() {
        let service = HeadphoneMotionService()
        service.forcesDebugMotionStub = true
        var connects = 0
        service.onConnect = { _ in
            connects += 1
            guard connects < 5 else { return }
            service.start()
        }
        service.start()
        XCTAssertEqual(connects, 1)
        XCTAssertTrue(service.isRunning)
        service.stop()
    }
}
#endif
