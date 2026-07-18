import XCTest

final class OpponentTendencyUITests: XCTestCase {
    @MainActor
    func testFirstUnderstoodPublicDecisionRevealsOneLocalizedTendency() {
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

        let disclosedOpponent = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND value BEGINSWITH %@",
                "phase2.opponent.",
                "Tendenz:"
            )
        ).firstMatch
        XCTAssertTrue(
            disclosedOpponent.waitForExistence(timeout: 12),
            "Die erste verstandene, öffentliche Gegnerentscheidung muss genau eine Tendenz freigeben."
        )

        let disclosedOpponents = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND value BEGINSWITH %@",
                "phase2.opponent.",
                "Tendenz:"
            )
        )
        XCTAssertEqual(disclosedOpponents.count, 1,
                       "Nur der tatsächlich beobachtete Gegner darf markiert werden.")

        let caveat = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Eine Tendenz, kein Versprechen.")
        ).firstMatch
        XCTAssertTrue(caveat.waitForExistence(timeout: 2),
                      "Die sichtbare Erklärung muss die Tendenz ausdrücklich als Nicht-Versprechen einordnen.")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "phase2-opponent-public-tendency"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
