#if INTERNAL_QA
import XCTest

@MainActor
final class InternalCoinQAUITests: XCTestCase {
    func testInternalCoinQAIsReachableFromSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-settings"]
        app.launch()

        let entry = app.buttons["settings.internalCoinQA"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        entry.tap()
        XCTAssertTrue(app.buttons["internal.coinQA.play"].waitForExistence(timeout: 5))
    }

    func testInternalCoinQAPlaysCertifiedDropToRest() {
        let app = XCUIApplication()
        app.launchArguments = ["-internalCoinQA"]
        app.launch()

        let play = app.buttons["internal.coinQA.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        play.tap()

        let drop = app.otherElements["phase2.coin.transcript.drop"]
        XCTAssertTrue(drop.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForValue(drop, containing: "resting", timeout: 5))
        XCTAssertTrue(drop.valueDescription.contains("contact 1"))
        XCTAssertTrue(drop.valueDescription.contains("rest 1"))
    }

    func testInternalCoinQAReducedMotionReachesSameRest() {
        let app = XCUIApplication()
        app.launchArguments = ["-internalCoinQA"]
        app.launch()

        let reduced = app.buttons["Reduziert"]
        XCTAssertTrue(reduced.waitForExistence(timeout: 8))
        reduced.tap()
        app.buttons["internal.coinQA.play"].tap()

        let drop = app.otherElements["phase2.coin.transcript.drop"]
        XCTAssertTrue(drop.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForValue(drop, containing: "resting", timeout: 2))
        XCTAssertTrue(drop.valueDescription.contains("contact 1"))
        XCTAssertTrue(drop.valueDescription.contains("rest 1"))
    }

    private func waitForValue(_ element: XCUIElement,
                              containing expected: String,
                              timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

private extension XCUIElement {
    var valueDescription: String { value as? String ?? "" }
}
#endif
