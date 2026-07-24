import XCTest

final class FirstRunCinematicUITests: XCTestCase {
    @MainActor
    func testEveryCinematicSceneKeepsTheTableReadableAt390x844() throws {
        XCUIDevice.shared.orientation = .portrait
        let sceneNames = [
            "darkness", "contact", "table-reveal", "players-arrive",
            "deck-settles", "invitation", "ready"
        ]

        for sceneIndex in 0...6 {
            let app = XCUIApplication()
            app.launchArguments = [
                "-firstRun",
                "-firstRunScene=\(sceneIndex)",
                "-players=4",
                "-sound", "false",
                "-haptics", "false",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
                "-AppleLanguages", "(de)",
                "-AppleLocale", "de_DE"
            ]
            app.launch()

            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 4))
            try XCTSkipUnless(
                abs(window.frame.width - 390) <= 1 && abs(window.frame.height - 844) <= 1,
                "Dieser Film-Gate bewertet den 390 × 844-Referenzviewport."
            )

            let probe = app.descendants(matching: .any)["firstRun.cinematic.scene"]
            XCTAssertTrue(probe.waitForExistence(timeout: 4))
            XCTAssertEqual(probe.label, sceneNames[sceneIndex])

            let table = app.descendants(matching: .any)["firstRun.cinematic.table"].firstMatch
            XCTAssertTrue(table.waitForExistence(timeout: 2))
            XCTAssertTrue(window.frame.intersects(table.frame))

            if sceneIndex < 6 {
                let skip = app.buttons["firstRun.cinematic.skip"]
                XCTAssertTrue(skip.waitForExistence(timeout: 2))
                XCTAssertTrue(window.frame.contains(skip.frame))
            } else {
                let title = app.descendants(matching: .any)["firstRun.intro.title"]
                let body = app.descendants(matching: .any)["firstRun.intro.body"]
                let primary = app.buttons["firstRun.intro.primary"]
                let secondary = app.buttons["firstRun.intro.secondary"]
                XCTAssertTrue(title.waitForExistence(timeout: 2))
                XCTAssertTrue(body.waitForExistence(timeout: 2))
                XCTAssertTrue(primary.waitForExistence(timeout: 2))
                XCTAssertTrue(secondary.waitForExistence(timeout: 2))
                XCTAssertEqual(primary.label, "Mitspielen")
                XCTAssertTrue(window.frame.contains(title.frame))
                XCTAssertTrue(window.frame.contains(body.frame))
                XCTAssertFalse(title.frame.intersects(body.frame))
                XCTAssertFalse(body.frame.intersects(primary.frame))
                XCTAssertFalse(primary.frame.intersects(secondary.frame))
                XCTAssertTrue(window.frame.contains(primary.frame))
                XCTAssertTrue(window.frame.contains(secondary.frame))
            }

            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "first-run-cinematic-scene-\(sceneIndex)-390x844"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    @MainActor
    func testReducedMotionImmediatelyOffersASeat() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-firstRun",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let body = app.descendants(matching: .any)["firstRun.intro.body"]
        let primary = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(body.waitForExistence(timeout: 4))
        XCTAssertTrue(primary.waitForExistence(timeout: 2))
        XCTAssertTrue(primary.isHittable)
        XCTAssertEqual(primary.label, "Mitspielen")
        XCTAssertEqual(body.label, "Die erste Runde spielen wir zusammen.")
    }

    @MainActor
    func testNaturalTimelineReachesInvitationWithinNineSeconds() {
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
        ]
        app.launch()

        let primary = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 9))
        XCTAssertEqual(primary.label, "Mitspielen")
        XCTAssertTrue(primary.isHittable)
    }

    @MainActor
    func testReadyStateFitsACompactPhoneWithoutCollisions() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-firstRun",
            "-firstRunScene=6",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4))
        try XCTSkipUnless(
            abs(window.frame.width - 375) <= 1 && abs(window.frame.height - 667) <= 1,
            "Dieser Gate bewertet den 375 × 667-Kompaktviewport."
        )

        let title = app.descendants(matching: .any)["firstRun.intro.title"]
        let body = app.descendants(matching: .any)["firstRun.intro.body"]
        let primary = app.buttons["firstRun.intro.primary"]
        let secondary = app.buttons["firstRun.intro.secondary"]
        for element in [title, body, primary, secondary] {
            XCTAssertTrue(element.waitForExistence(timeout: 4))
            XCTAssertTrue(window.frame.contains(element.frame))
        }
        XCTAssertFalse(title.frame.intersects(body.frame))
        XCTAssertFalse(body.frame.intersects(primary.frame))
        XCTAssertFalse(primary.frame.intersects(secondary.frame))

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "first-run-cinematic-ready-375x667"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
