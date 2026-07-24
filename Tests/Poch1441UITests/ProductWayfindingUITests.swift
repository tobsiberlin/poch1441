import XCTest

final class ProductWayfindingUITests: XCTestCase {
    @MainActor
    func testThreePlayerDealKeepsAllOpponentCardsVisible() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = commonArguments([
            "-dealTableauQA",
            "-players=3",
            "-reduceMotionQA"
        ])
        app.launch()

        let firstOpponent = app.descendants(matching: .any)["phase1.deal.seat.1"]
        let secondOpponent = app.descendants(matching: .any)["phase1.deal.seat.2"]
        XCTAssertTrue(firstOpponent.waitForExistence(timeout: 5))
        XCTAssertTrue(secondOpponent.waitForExistence(timeout: 5))
        XCTAssertEqual(firstOpponent.value as? String, "10")
        XCTAssertEqual(secondOpponent.value as? String, "10")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "phase1-three-player-complete-tableaux"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUtilityChromeStaysInsideEveryPortraitPhase() {
        XCUIDevice.shared.orientation = .portrait
        let stages: [[String]] = [
            [],
            ["-pochenStart"],
            ["-ausspielStart", "-holdPlayout"]
        ]

        for stageArguments in stages {
            let app = XCUIApplication()
            app.launchArguments = commonArguments(stageArguments)
            app.launch()

            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 4))
            for identifier in ["chrome.settings", "chrome.pause"] {
                let button = app.buttons[identifier]
                XCTAssertTrue(button.waitForExistence(timeout: 4))
                XCTAssertTrue(button.isHittable)
                XCTAssertTrue(window.frame.contains(button.frame),
                              "\(identifier) muss in jeder Phase vollständig im Display bleiben.")
            }
            app.terminate()
        }
    }

    @MainActor
    func testSettingsAreDirectlyVisibleAndOpenFromTheTable() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchPhase2()

        let settings = app.buttons["chrome.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 4),
                      "Einstellungen müssen direkt am Tisch sichtbar sein.")
        XCTAssertTrue(settings.isHittable,
                      "Der sichtbare Einstellungsbutton muss bedienbar sein.")
        XCTAssertGreaterThanOrEqual(settings.frame.width, 44)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44)

        settings.tap()
        XCTAssertTrue(app.otherElements["settings.panel"].waitForExistence(timeout: 2),
                      "Ein Tap muss die Einstellungen ohne Umweg öffnen.")
        attachScreenshot(named: "settings-from-table")
    }

    @MainActor
    func testPauseMenuLeadsThroughLearningRulesAndSettingsWithoutTechLanguage() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchPhase2()

        let pause = app.buttons["chrome.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 4))
        pause.tap()

        XCTAssertTrue(app.staticTexts["Deine Runde"].waitForExistence(timeout: 3))
        for label in ["Mit Hana spielen", "Regeln", "Einstellungen", "Zurück ins Spiel"] {
            XCTAssertTrue(app.buttons[label].exists,
                          "Im Pausenmenü fehlt die eindeutige Aktion \(label).")
        }
        attachScreenshot(named: "pause-menu-simple-wayfinding")

        app.buttons["Mit Hana spielen"].tap()
        XCTAssertTrue(app.staticTexts["Hana spielt mit"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["HANA"].exists)
        XCTAssertTrue(app.buttons["Runde beginnen"].exists)
        attachScreenshot(named: "learn-with-hana-simple-entry")

        app.buttons["xmark"].tap()
        XCTAssertTrue(app.buttons["chrome.pause"].waitForExistence(timeout: 3))
        app.buttons["chrome.pause"].tap()
        XCTAssertTrue(app.staticTexts["Deine Runde"].waitForExistence(timeout: 3))
        app.buttons["Regeln"].tap()
        XCTAssertTrue(app.staticTexts["Poch auf einen Blick"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Drei Wege zu gewinnen"].exists)
        XCTAssertTrue(app.buttons["Zurück zum Tisch"].exists)
        attachScreenshot(named: "rules-three-ways")

        let rulesBody = app.scrollViews["overlay.body"]
        XCTAssertTrue(rulesBody.exists)
        rulesBody.swipeUp()
        let fullBiddingRule = app.staticTexts[
            "Mit zwei gleichen Karten darfst du bieten. Bleiben mehrere, entscheidet die stärkste Gruppe."
        ]
        XCTAssertTrue(fullBiddingRule.waitForExistence(timeout: 2),
                      "Die entscheidende Poch-Regel darf nie mit Auslassungspunkten enden.")
        let fullPlayoutRule = app.staticTexts[
            "Eine Farbe läuft aufwärts. Wer die Reihe beendet, eröffnet neu."
        ]
        XCTAssertTrue(fullPlayoutRule.waitForExistence(timeout: 2),
                      "Auch die dritte Phase muss vollständig erreichbar und lesbar sein.")
        attachScreenshot(named: "rules-all-three-readable")

        app.buttons["Einstellungen"].tap()
        XCTAssertTrue(app.staticTexts["Dein Tisch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["settings.panel"].exists)
        XCTAssertFalse(app.staticTexts["Poch Disc · Graphit und R1"].exists)
        XCTAssertFalse(app.staticTexts["Impressum/Datenschutz vorbereitet"].exists)
        XCTAssertFalse(app.staticTexts["Folgt iOS Reduce Motion"].exists)
        XCTAssertTrue(app.buttons["Fertig"].exists)
        attachScreenshot(named: "settings-only-real-decisions")

        app.buttons["Fertig"].tap()
        XCTAssertFalse(app.otherElements["settings.panel"].exists)
    }

    @MainActor
    func testLivePhase2HasSeparatedDecisionActionOpponentAndHandZones() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchPhase2()

        let window = app.windows.firstMatch
        let board = app.images.matching(identifier: "table.world.phase2.board").firstMatch
        let decision = app.otherElements["phase2.decision"]
        let actions = app.otherElements["phase2.actions"]
        let hand = app.otherElements["phase2.hand"]
        let opponents = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase2.opponent.")
        )

        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        XCTAssertTrue(decision.waitForExistence(timeout: 4))
        XCTAssertTrue(actions.waitForExistence(timeout: 4))
        XCTAssertTrue(hand.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(opponents.count, 0)

        XCTAssertGreaterThanOrEqual(board.frame.width, 190,
                                    "Die Poch-Scheibe muss Phase 2 visuell tragen.")
        XCTAssertFalse(decision.frame.intersects(actions.frame),
                       "Erklärung und Aktionen brauchen getrennte Zonen.")
        XCTAssertFalse(actions.frame.intersects(hand.frame),
                       "Aktionen und Hand dürfen sich nicht überlagern.")

        for index in 0..<opponents.count {
            let opponent = opponents.element(boundBy: index).frame
            XCTAssertFalse(actions.frame.intersects(opponent),
                           "Aktionen und Gegnerreaktionen brauchen getrennte Zonen.")
            XCTAssertFalse(hand.frame.intersects(opponent),
                           "Gegner und eigene Hand brauchen getrennte Zonen.")
        }

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "phase2-live-wayfinding-\(Int(window.frame.width))x\(Int(window.frame.height))"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func launchPhase2() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = commonArguments(["-pochenStart"])
        app.launch()
        return app
    }

    private func commonArguments(_ stageArguments: [String]) -> [String] {
        stageArguments + [
            "-coachOff",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
