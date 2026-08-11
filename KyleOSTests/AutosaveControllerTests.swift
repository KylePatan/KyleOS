import XCTest
@testable import KyleOS

final class AutosaveControllerTests: XCTestCase {

    func testScheduleSaveFiresAfterDelay() {
        let controller = AutosaveController(delay: 0.1)
        let expectation = expectation(description: "autosave fires")
        controller.scheduleSave { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRapidCallsCollapseIntoASingleSave() {
        let controller = AutosaveController(delay: 0.2)
        var fireCount = 0
        let expectation = expectation(description: "autosave fires once")

        for _ in 0..<5 {
            controller.scheduleSave {
                fireCount += 1
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fireCount, 1, "A burst of rapid edits must collapse into one debounced save")
    }

    func testSaveImmediatelyCancelsPendingAndRunsSynchronously() {
        let controller = AutosaveController(delay: 5.0)
        var pendingFired = false
        var immediateFired = false

        controller.scheduleSave { pendingFired = true }
        controller.saveImmediately { immediateFired = true }

        XCTAssertTrue(immediateFired)
        XCTAssertFalse(controller.hasPendingSave)

        // Give the (now-cancelled) original delayed work a chance to fire, if it were going to.
        let notExpectedToFire = expectation(description: "pending save should not fire")
        notExpectedToFire.isInverted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if pendingFired { notExpectedToFire.fulfill() }
        }
        wait(for: [notExpectedToFire], timeout: 0.5)
    }
}
