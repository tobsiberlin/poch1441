import XCTest

@MainActor
final class TranscriptCoinDropUITests: XCTestCase {
    func testStandardQueenDropReachesRestWithExactlyOneCoin() {
        let app = launch(arguments: ["-transcriptCoinQA"])
        let drop = app.otherElements["phase2.coin.transcript.drop"]
        XCTAssertTrue(drop.waitForExistence(timeout: 18))
        XCTAssertTrue(waitForValue(drop, containing: "resting", timeout: 5))
        XCTAssertTrue(drop.valueDescription.contains("coin 1/1"))
        XCTAssertTrue(drop.valueDescription.contains("contact 1"))
        XCTAssertTrue(drop.valueDescription.contains("rest 1"))
        XCTAssertTrue(drop.valueDescription.contains("moving 0"))
    }

    func testReducedMotionQueenDropReachesSameRestSynchronously() {
        let app = launch(arguments: ["-transcriptCoinReducedMotionQA"])
        let drop = app.otherElements["phase2.coin.transcript.drop"]
        XCTAssertTrue(drop.waitForExistence(timeout: 18))
        XCTAssertTrue(waitForValue(drop, containing: "resting", timeout: 2))
        XCTAssertTrue(drop.valueDescription.contains("coin 1/1"))
        XCTAssertTrue(drop.valueDescription.contains("contact 1"))
        XCTAssertTrue(drop.valueDescription.contains("rest 1"))
    }

    func testDefaultTrackBPhase2KeepsTranscriptHookAbsent() {
        let app = launch(arguments: [])
        XCTAssertFalse(app.otherElements["phase2.coin.transcript.drop"]
            .waitForExistence(timeout: 3))
    }

    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pochenStart", "-tableWorld=unterwegs"] + arguments
        app.launch()
        return app
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
