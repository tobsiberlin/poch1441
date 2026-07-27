import XCTest

final class GuidedPlayoutUITests: XCTestCase {
    @MainActor
    func testCompactPhoneKeepsGuidanceOpponentsAndHandSeparated() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchGuidedPlayout(reduceMotion: false)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 6))
        try XCTSkipUnless(
            abs(window.frame.width - 375) <= 1 && abs(window.frame.height - 667) <= 1,
            "Dieses Gate bewertet ausschließlich das 375 × 667-Referenzgerät."
        )
        openPlayoutCurtain(in: app)

        let jack = app.buttons["phase3.hand.card.hearts.11"]
        XCTAssertTrue(waitUntil(timeout: 8) { jack.isEnabled && jack.isHittable })
        jack.tap()

        let queen = app.buttons["phase3.hand.card.hearts.12"]
        XCTAssertTrue(waitUntil(timeout: 8) { queen.isEnabled && queen.isHittable })
        queen.tap()

        let explanation = app.descendants(matching: .any)["phase3.guided.explanation"]
        let advance = app.buttons["phase3.guided.advance"]
        let opponentPortraits = app.images.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Opponent")
        )
        let handCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        )
        XCTAssertTrue(explanation.waitForExistence(timeout: 6))
        XCTAssertTrue(advance.waitForExistence(timeout: 6))
        XCTAssertEqual(opponentPortraits.count, 3)
        XCTAssertGreaterThan(handCards.count, 1)

        let portraits = opponentPortraits.allElementsBoundByIndex
        let cards = handCards.allElementsBoundByIndex
        for element in [explanation, advance] + portraits {
            XCTAssertTrue(window.frame.contains(element.frame),
                          "Alle Lernbereiche müssen auf dem kompakten iPhone sichtbar bleiben.")
        }
        for card in cards {
            XCTAssertTrue(window.frame.intersects(card.frame),
                          "Jede Handkarte muss im kompakten Fächer sichtbar bleiben.")
            XCTAssertLessThan(card.frame.minY, window.frame.maxY - 44,
                              "Von jeder Karte muss mehr als nur ein Rand sichtbar sein.")
        }
        let opponentTop = portraits.map(\.frame.minY).min() ?? CGFloat.greatestFiniteMagnitude
        let opponentBottom = portraits.map(\.frame.maxY).max() ?? 0
        let handTop = cards.map(\.frame.minY).min() ?? CGFloat.greatestFiniteMagnitude
        XCTAssertFalse(explanation.frame.intersects(advance.frame))
        XCTAssertLessThanOrEqual(advance.frame.maxY + 4, opponentTop)
        XCTAssertLessThanOrEqual(opponentBottom + 4, handTop)

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "guided-playout-compact-375x667"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testCompactLandscapeUsesFourNonOverlappingStageZones() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchGuidedPlayout(
            reduceMotion: false,
            additionalArguments: ["-landscapeQA"]
        )
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 6))
        let landscapePredicate = NSPredicate { _, _ in
            abs(window.frame.width - 667) <= 1
                && abs(window.frame.height - 375) <= 1
        }
        let landscapeExpectation = XCTNSPredicateExpectation(
            predicate: landscapePredicate,
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [landscapeExpectation], timeout: 6), .completed,
                       "Der Gate muss das echte 667 × 375-Querformat erreichen.")
        openPlayoutCurtain(in: app)
        advanceToFirstOpponentChoice(in: app)

        // SwiftUI propagates the enclosing table world's identifier to combined
        // accessibility containers. Their stable, localized QA labels still expose
        // the exact visual region frames that this overlap gate must validate.
        let panel = region(in: app, label: "Erklärung und Aktion")
        let played = region(in: app, label: "Gespielte Karten")
        let opponents = region(in: app, label: "Gegnerbereich")
        let hand = region(in: app, label: "Deine Handkarten")
        let regions = [panel, played, opponents, hand]

        for region in regions {
            XCTAssertTrue(region.waitForExistence(timeout: 6))
            XCTAssertTrue(window.frame.contains(region.frame),
                          "Jede Landscape-Zone muss vollständig im Fenster liegen: \(region.identifier).")
            XCTAssertGreaterThan(region.frame.width, 40)
            XCTAssertGreaterThan(region.frame.height, 40)
        }

        for firstIndex in regions.indices {
            for secondIndex in regions.indices where secondIndex > firstIndex {
                let first = regions[firstIndex]
                let second = regions[secondIndex]
                XCTAssertFalse(
                    first.frame.insetBy(dx: -2, dy: -2).intersects(second.frame),
                    "Die Landscape-Zonen \(first.identifier) und \(second.identifier) dürfen sich nicht berühren."
                )
            }
        }

        let advance = app.buttons["phase3.guided.advance"]
        XCTAssertTrue(advance.exists && advance.isHittable)
        XCTAssertTrue(panel.frame.contains(advance.frame),
                      "Die Bestätigung gehört vollständig in die Erklärzone.")

        let handCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        ).allElementsBoundByIndex
        XCTAssertGreaterThan(handCards.count, 1)
        for card in handCards {
            XCTAssertTrue(window.frame.intersects(card.frame))
            XCTAssertFalse(card.frame.intersects(panel.frame))
            XCTAssertFalse(card.frame.intersects(opponents.frame))
        }

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "guided-playout-compact-landscape-667x375"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSpatialCardMustLandBeforeTheNextGuidedActionUnlocks() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchGuidedPlayout(reduceMotion: false)
        openPlayoutCurtain(in: app)

        let jack = app.buttons["phase3.hand.card.hearts.11"]
        XCTAssertTrue(waitUntil(timeout: 8) { jack.isEnabled && jack.isHittable })
        let queen = app.buttons["phase3.hand.card.hearts.12"]
        XCTAssertTrue(queen.waitForExistence(timeout: 4))
        jack.tap()

        XCTAssertFalse(queen.isEnabled,
                       "Die nächste Handlung darf vor dem sichtbaren Kartenkontakt nicht freigegeben werden.")
        XCTAssertTrue(waitUntil(timeout: 5) { queen.isEnabled && queen.isHittable })
    }

    @MainActor
    func testFirstGuidedRowWaitsForUnderstandingAndReturnsARealChoice() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchGuidedPlayout(reduceMotion: true)

        let phase = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase.waitForExistence(timeout: 8))
        openPlayoutCurtain(in: app)

        let jack = app.buttons["phase3.hand.card.hearts.11"]
        XCTAssertTrue(jack.waitForExistence(timeout: 8))
        XCTAssertTrue(waitUntil(timeout: 8) { jack.isEnabled && jack.isHittable })
        jack.tap()

        let queen = app.buttons["phase3.hand.card.hearts.12"]
        XCTAssertTrue(waitUntil(timeout: 8) { queen.isEnabled && queen.isHittable },
                      "Die eigene Pflichtkarte muss als echte Handlung beim Menschen bleiben.")
        queen.tap()

        let nextCard = app.buttons["phase3.guided.advance"]
        XCTAssertTrue(nextCard.waitForExistence(timeout: 8),
                      "Der Gegnerzug darf den erklärenden Zustand nicht automatisch überfahren.")
        XCTAssertTrue(nextCard.isHittable)
        XCTAssertTrue(nextCard.label.contains("legt"),
                      "Die Bestätigung soll die konkrete nächste Karte und Person nennen.")
        nextCard.tap()

        let ace = app.buttons["phase3.hand.card.hearts.14"]
        XCTAssertTrue(waitUntil(timeout: 8) { ace.isEnabled && ace.isHittable })
        ace.tap()

        let newLeadTitle = app.staticTexts["WÄHLE DEINE NEUE STARTKARTE"]
        XCTAssertTrue(newLeadTitle.waitForExistence(timeout: 8))

        let handCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        )
        XCTAssertTrue(waitUntil(timeout: 8) {
            handCards.allElementsBoundByIndex.filter { $0.isEnabled && $0.isHittable }.count >= 2
        }, "Nach der Lernreihe muss der Mensch zwischen mindestens zwei legalen Starts wählen.")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "guided-playout-new-lead-choice-390x844"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func launchGuidedPlayout(
        reduceMotion: Bool,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialPlayout",
            "-guidedPlayoutSeedQA=20",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ] + additionalArguments + (reduceMotion ? ["-reduceMotionQA"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func advanceToFirstOpponentChoice(in app: XCUIApplication) {
        let jack = app.buttons["phase3.hand.card.hearts.11"]
        XCTAssertTrue(waitUntil(timeout: 8) { jack.isEnabled && jack.isHittable })
        jack.tap()

        let queen = app.buttons["phase3.hand.card.hearts.12"]
        XCTAssertTrue(waitUntil(timeout: 8) { queen.isEnabled && queen.isHittable })
        queen.tap()

        let advance = app.buttons["phase3.guided.advance"]
        XCTAssertTrue(advance.waitForExistence(timeout: 8))
        XCTAssertTrue(advance.isHittable)
    }

    @MainActor
    private func region(in app: XCUIApplication, label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    @MainActor
    private func openPlayoutCurtain(in app: XCUIApplication) {
        let phase = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase.waitForExistence(timeout: 8))
        let curtain = app.buttons["tutorial.phaseCurtain.continue"]
        if curtain.waitForExistence(timeout: 3),
           waitUntil(timeout: 3, condition: { curtain.isHittable }) {
            curtain.tap()
        }
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval,
                           condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.10))
        }
        return condition()
    }
}
