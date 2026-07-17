import XCTest

final class FirstRunUITests: XCTestCase {
    @MainActor
    func testFirstRunKeepsItsMeaningAcrossRotation() {
        let app = XCUIApplication()
        app.launchArguments = localizedArguments(["-firstRun", "-players=4"])

        XCUIDevice.shared.orientation = .portrait
        app.launch()

        assertWindow(in: app, hasOrientation: .portrait)
        assertIntroContract(in: app)
        attachScreenshot(of: app, named: "first-run-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        assertWindow(in: app, hasOrientation: .landscape)

        assertIntroContract(in: app)
        attachScreenshot(of: app, named: "first-run-landscape")
    }

    @MainActor
    func testFirstContactAndLearningStates() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = localizedArguments(["-firstRun", "-players=4"])
        app.launch()

        let enterTable = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(enterTable.waitForExistence(timeout: 4))
        enterTable.tap()

        let openingToken = app.buttons["firstRun.openingToken"]
        guard openingToken.waitForExistence(timeout: 4) else {
            XCTFail("Die Track-A-Poch-Scheibe muss als interaktives Element existieren.")
            return
        }
        let openingTarget = app.descendants(matching: .any)["firstRun.openingTarget"]
        guard openingTarget.waitForExistence(timeout: 4) else {
            XCTFail("Die Mitte muss als verständliches Drag- und VoiceOver-Ziel existieren.")
            return
        }
        openingToken.tap()

        let nextAction = app.buttons["firstRun.coachAction"]
        guard nextAction.waitForExistence(timeout: 4) else {
            XCTFail("Der erste Kontakt muss erst nach der Zählermutation zur nächsten Aktion führen.")
            return
        }
        assertLearningState("Orientieren", in: app)
        assertFixedOpponents(in: app)
        attachScreenshot(of: app, named: "first-contact-landed")

        let checkpoints: [(step: Int, state: String, name: String)] = [
            (3, "Verbinden", "first-card"),
            (4, "Verbinden", "trump-ready"),
            (5, "Verbinden", "meld-connect"),
            (6, "Beweisen", "meld-prove"),
            (7, "Loslassen", "meld-release")
        ]

        for checkpoint in checkpoints {
            app.terminate()
            app.launchArguments = localizedArguments([
                "-tutorialSeed",
                "-tutorialMeldStep=\(checkpoint.step)",
                "-players=4"
            ])
            app.launch()
            assertLearningState(checkpoint.state, in: app)
            assertFixedOpponents(in: app)
            attachScreenshot(of: app, named: checkpoint.name)
        }
    }

    @MainActor
    private func assertWindow(in app: XCUIApplication, hasOrientation orientation: ExpectedOrientation) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3), "Das Hauptfenster muss für die Rotationsprüfung existieren.")

        let predicate = NSPredicate { _, _ in
            switch orientation {
            case .portrait:
                return window.frame.height > window.frame.width
            case .landscape:
                return window.frame.width > window.frame.height
            }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 4),
            .completed,
            "Das App-Fenster muss die angeforderte Orientierung vollständig angenommen haben."
        )
    }

    @MainActor
    private func assertIntroContract(in app: XCUIApplication) {
        for opponent in ["Hana", "Noah", "Jonas"] {
            XCTAssertTrue(
                app.staticTexts[opponent].waitForExistence(timeout: 3),
                "Der feste Tutorialplatz \(opponent) muss sichtbar bleiben."
            )
        }

        XCTAssertTrue(
            app.buttons.firstMatch.waitForExistence(timeout: 3),
            "Die primäre First-Run-Aktion muss erreichbar bleiben."
        )
    }

    @MainActor
    private func assertFixedOpponents(in app: XCUIApplication) {
        let windowFrame = app.windows.firstMatch.frame
        for seat in 1...3 {
            let opponent = app.descendants(matching: .any)["firstRun.opponent.\(seat)"]
            XCTAssertTrue(
                opponent.waitForExistence(timeout: 4),
                "Tutorialplatz \(seat) muss im selben semantischen Sitz sichtbar bleiben."
            )
            XCTAssertTrue(
                windowFrame.intersects(opponent.frame) && opponent.frame.width >= 44 && opponent.frame.height >= 44,
                "Tutorialplatz \(seat) muss mit sichtbarer Porträtfläche im App-Fenster liegen."
            )
        }
    }

    @MainActor
    private func assertLearningState(_ expected: String, in app: XCUIApplication) {
        let state = app.descendants(matching: .any)["firstRun.learningState"]
        XCTAssertTrue(state.waitForExistence(timeout: 4))

        let predicate = NSPredicate { _, _ in
            (state.value as? String) == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 4),
            .completed,
            "Der sichtbare Lernzustand muss \(expected) sein."
        )
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        Thread.sleep(forTimeInterval: 0.35)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func localizedArguments(_ arguments: [String]) -> [String] {
        arguments + ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    }
}

private enum ExpectedOrientation {
    case portrait
    case landscape
}
