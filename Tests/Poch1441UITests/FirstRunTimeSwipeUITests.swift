import XCTest

final class FirstRunTimeSwipeUITests: XCTestCase {
    @MainActor
    func testPreludeComesBeforeTimelineAndEntersIt() {
        let app = launchApp()

        XCTAssertTrue(app.otherElements["firstRun.timeSwipe.prelude"]
            .waitForExistence(timeout: 4))
        XCTAssertFalse(app.otherElements["firstRun.timeSwipe.stage"].exists)

        enterTimeline(app)

        XCTAssertTrue(app.otherElements["firstRun.timeSwipe.stage"]
            .waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["firstRun.timeSwipe.prelude"].exists)
    }

    @MainActor
    func testFrozenHistoricalStatesStayReadable() {
        let states: [(progress: String, title: String, name: String)] = [
            ("0", "Pokers älterer Bruder. Seit 1441.", "origin"),
            ("0.55", "Über Poque führt die Spur weiter.", "branch"),
            ("1", "Drei Chancen. Eine Runde.", "today")
        ]

        for state in states {
            let app = launchApp(extra: ["-firstRunTimeProgress=\(state.progress)"])
            let window = app.windows.firstMatch
            let title = app.descendants(matching: .any)["firstRun.timeSwipe.title"]
            let body = app.descendants(matching: .any)["firstRun.timeSwipe.body"]

            XCTAssertTrue(window.waitForExistence(timeout: 4))
            XCTAssertTrue(title.waitForExistence(timeout: 4))
            XCTAssertTrue(body.waitForExistence(timeout: 2))
            XCTAssertEqual(title.label, state.title)
            XCTAssertTrue(window.frame.contains(title.frame))
            XCTAssertTrue(window.frame.contains(body.frame))
            XCTAssertFalse(title.frame.intersects(body.frame))

            if state.progress == "1" {
                let primary = app.buttons["firstRun.intro.primary"]
                XCTAssertTrue(primary.waitForExistence(timeout: 2))
                XCTAssertEqual(primary.label, "An den Tisch")
                XCTAssertTrue(primary.isHittable)
                XCTAssertFalse(app.buttons["firstRun.timeSwipe.skip"].exists)
            } else {
                XCTAssertTrue(app.buttons["firstRun.timeSwipe.skip"].exists)
            }

            attachScreenshot(named: "first-run-time-swipe-\(state.name)")
            app.terminate()
        }
    }

    @MainActor
    func testDirectSwipeCanReachTodayAndReverse() {
        let app = launchApp()
        enterTimeline(app)
        let stage = app.otherElements["firstRun.timeSwipe.stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 4))

        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.48))
            .press(forDuration: 0.05,
                   thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.48)))
        XCTAssertTrue(app.buttons["firstRun.intro.primary"].waitForExistence(timeout: 3))

        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.48))
            .press(forDuration: 0.05,
                   thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.48)))
        let title = app.descendants(matching: .any)["firstRun.timeSwipe.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        XCTAssertEqual(title.label, "Pokers älterer Bruder. Seit 1441.")
    }

    @MainActor
    func testSkipAndSeatEnterTheGuidedRound() {
        let app = launchApp()
        enterTimeline(app)
        let skip = app.buttons["firstRun.timeSwipe.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 4))
        skip.tap()

        let primary = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 3))
        primary.tap()

        XCTAssertTrue(app.buttons["firstRun.openingToken"].waitForExistence(timeout: 5),
                      "The new opening must hand off to the actual guided table.")
    }

    @MainActor
    func testReducedMotionUsesDiscreteReadableChapters() {
        let app = launchApp(extra: ["-reduceMotionQA"])
        enterTimeline(app)
        XCTAssertTrue(app.scrollViews["firstRun.timeSwipe.discrete"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.descendants(matching: .any)["firstRun.timeSwipe.title"].label,
                       "Pokers älterer Bruder. Seit 1441.")

        let next = app.buttons["firstRun.timeSwipe.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 2))
        next.tap()
        XCTAssertEqual(app.descendants(matching: .any)["firstRun.timeSwipe.title"].label,
                       "Über Poque führt die Spur weiter.")
        next.tap()
        XCTAssertTrue(app.buttons["firstRun.intro.primary"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchApp(extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-firstRun",
            "-firstRunOpening=timeSwipe",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ] + extra
        app.launch()
        return app
    }

    @MainActor
    private func enterTimeline(_ app: XCUIApplication) {
        let button = app.buttons["firstRun.timeSwipe.prelude.primary"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
