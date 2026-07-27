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
            ("0", "1441: Ein Tisch, drei Chancen.", "origin"),
            ("0.55", "Poch hinterlässt Spuren im Poker.", "branch"),
            ("1", "Jetzt bist du dran.", "today")
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

        // Die direkte Zeitgeste gehört bewusst auf die Bildbühne. Der untere
        // Textfilm bleibt für CTAs und lesbare Kopie reserviert.
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.28))
            .press(forDuration: 0.05,
                   thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.28)))
        XCTAssertTrue(app.buttons["firstRun.intro.primary"].waitForExistence(timeout: 3))

        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.28))
            .press(forDuration: 0.05,
                   thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.28)))
        let title = app.descendants(matching: .any)["firstRun.timeSwipe.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        XCTAssertEqual(title.label, "1441: Ein Tisch, drei Chancen.")
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
                       "1441: Ein Tisch, drei Chancen.")

        let next = app.buttons["firstRun.timeSwipe.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 2))
        next.tap()
        XCTAssertEqual(app.descendants(matching: .any)["firstRun.timeSwipe.title"].label,
                       "Poch hinterlässt Spuren im Poker.")
        next.tap()
        XCTAssertTrue(app.buttons["firstRun.intro.primary"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testProductionOpeningSurvivesCompactOrientations() {
        let portrait = launchApp(extra: ["-portraitQA"])
        let portraitWindow = portrait.windows.firstMatch
        XCTAssertTrue(portrait.otherElements["firstRun.timeSwipe.prelude"].waitForExistence(timeout: 4))
        assertWindowOrientation(.portrait, in: portrait)
        XCTAssertEqual(portraitWindow.frame.size, CGSize(width: 375, height: 667),
                       "Der kompakte Hochformat-Gate muss wirklich auf dem iPhone SE laufen.")
        portrait.terminate()

        let landscape = launchApp(extra: ["-landscapeQA"])
        let landscapeWindow = landscape.windows.firstMatch
        XCTAssertTrue(landscape.otherElements["firstRun.timeSwipe.prelude"].waitForExistence(timeout: 4))
        assertWindowOrientation(.landscape, in: landscape)
        XCTAssertEqual(landscapeWindow.frame.size, CGSize(width: 667, height: 375),
                       "Der kompakte Querformat-Gate muss wirklich auf dem iPhone SE laufen.")

        enterTimeline(landscape)
        let compactTimeline = landscape.scrollViews["firstRun.timeSwipe.discrete"]
        XCTAssertTrue(compactTimeline.waitForExistence(timeout: 4),
                      "Kurzes Querformat braucht die scrollbare Kapitelansicht statt einer verdeckten Filmkarte.")
        let title = landscape.descendants(matching: .any)["firstRun.timeSwipe.title"]
        let body = landscape.descendants(matching: .any)["firstRun.timeSwipe.body"]
        let next = landscape.buttons["firstRun.timeSwipe.next"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertFalse(title.frame.intersects(body.frame))
        XCTAssertFalse(body.frame.intersects(next.frame))
        XCTAssertTrue(next.isHittable)
        landscape.terminate()
    }

    @MainActor
    private func launchApp(extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-firstRun",
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
    private func assertWindowOrientation(_ orientation: WindowOrientation,
                                         in app: XCUIApplication,
                                         timeout: TimeInterval = 5) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: timeout))
        let expectedLandscape = orientation == .landscape
        let predicate = NSPredicate { _, _ in
            let frame = window.frame
            return expectedLandscape ? frame.width > frame.height : frame.height > frame.width
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "Das produktive Onboarding muss die angeforderte Orientierung annehmen. " +
                       "Fenster: \(window.frame)")
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

private enum WindowOrientation {
    case portrait
    case landscape
}
