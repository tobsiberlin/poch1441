import XCTest

final class OpponentTendencyUITests: XCTestCase {
    @MainActor
    func testGuidedRoundSuppressesOpponentTendenciesAfterPublicDecision() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialBidding",
            "-tutorialBiddingStep=2",
            "-pochActionQA",
            "-reduceMotionQA",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let curtain = app.buttons["tutorial.phaseCurtain.continue"]
        if curtain.waitForExistence(timeout: 3), curtain.isHittable {
            curtain.tap()
        }

        let opponents = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase2.opponent.")
        )
        XCTAssertGreaterThan(opponents.count, 0,
                             "Die geführte Poch-Runde muss ihre Gegner sichtbar aufbauen.")

        // -pochActionQA führt nach dem Prelude eine echte öffentliche Aktion aus.
        // Die Lernrunde bleibt trotzdem auf der Kernregel fokussiert und zeigt
        // weder Metagame-Tendenzen noch deren Caveat.
        Thread.sleep(forTimeInterval: 4.5)
        let disclosedOpponent = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND value BEGINSWITH %@",
                "phase2.opponent.",
                "Tendenz:"
            )
        ).firstMatch
        XCTAssertFalse(disclosedOpponent.exists,
                       "Tendenzen gehören nicht in die geführte erste Runde.")

        let disclosedOpponents = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND value BEGINSWITH %@",
                "phase2.opponent.",
                "Tendenz:"
            )
        )
        XCTAssertEqual(disclosedOpponents.count, 0,
                       "Kein Gegner darf im Tutorial mit einer Tendenz markiert werden.")

        let caveat = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Eine Tendenz, kein Versprechen.")
        ).firstMatch
        XCTAssertFalse(caveat.exists,
                       "Ohne Tendenz darf auch kein fortgeschrittener Caveat erscheinen.")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "phase2-guided-opponents-without-tendencies"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
