import XCTest

final class GuidedPlayoutUITests: XCTestCase {
    @MainActor
    func testFirstLeadOffersARealChoiceAndAcceptsANonScriptedCard() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchGuidedPlayout(reduceMotion: true)
        openPlayoutCurtain(in: app)

        let handCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        )
        XCTAssertTrue(handCards.firstMatch.waitForExistence(timeout: 8))
        let initialCount = handCards.count
        let choices = handCards.allElementsBoundByIndex.filter {
            $0.isEnabled && $0.isHittable
        }
        XCTAssertGreaterThanOrEqual(
            choices.count,
            2,
            "Schon die erste Reihe muss mindestens zwei echte, legale Startkarten anbieten."
        )

        guard let alternative = choices.first(where: {
            $0.identifier != "phase3.hand.card.hearts.11"
        }) else {
            XCTFail("Die erste Wahl braucht mindestens eine Alternative zum geskripteten Herz-Buben.")
            return
        }
        let chosenIdentifier = alternative.identifier
        alternative.tap()

        XCTAssertTrue(waitUntil(timeout: 8) {
            handCards.count == initialCount - 1
        }, "Die frei gewählte Karte muss die sichtbare Hand wirklich verlassen.")
        XCTAssertFalse(
            app.buttons[chosenIdentifier].exists,
            "Die gewählte Alternative darf nicht als verdeckte oder unsichtbar blockierte Handkarte zurückbleiben."
        )
        let playedIdentifier = chosenIdentifier.replacingOccurrences(
            of: "phase3.hand.card.",
            with: "phase3.played.card."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[playedIdentifier].waitForExistence(timeout: 5),
            "Die frei gewählte Startkarte muss sichtbar in der neuen Reihe landen."
        )
    }

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
        let playedCards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.played.card.")
        )
        XCTAssertTrue(explanation.waitForExistence(timeout: 6))
        XCTAssertTrue(advance.waitForExistence(timeout: 6))
        XCTAssertEqual(opponentPortraits.count, 3)
        XCTAssertGreaterThan(handCards.count, 1)
        XCTAssertTrue(playedCards.firstMatch.waitForExistence(timeout: 6))

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
        for card in playedCards.allElementsBoundByIndex {
            XCTAssertFalse(card.frame.intersects(explanation.frame),
                           "Gespielte Karten dürfen nicht unter der Erklärung abgeschnitten werden.")
        }
        XCTAssertLessThanOrEqual(advance.frame.maxY + 4, opponentTop)
        XCTAssertLessThanOrEqual(opponentBottom + 4, handTop)
        assertAdvance(advance, isAnchoredToItsNamedOpponentIn: app)

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

        let explanation = app.descendants(matching: .any)["phase3.guided.explanation"]
        let advance = app.buttons["phase3.guided.advance"]
        let playedCards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.played.card.")
        )
        let opponentPortraits = app.images.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.opponent.")
        )
        let handCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        )

        XCTAssertTrue(explanation.waitForExistence(timeout: 6))
        XCTAssertTrue(advance.waitForExistence(timeout: 6))
        XCTAssertTrue(playedCards.firstMatch.waitForExistence(timeout: 6))
        XCTAssertTrue(opponentPortraits.firstMatch.waitForExistence(timeout: 6))
        XCTAssertTrue(handCards.firstMatch.waitForExistence(timeout: 6))

        let regions: [(name: String, frame: CGRect)] = [
            ("Anleitung", explanation.frame),
            ("Ausgespielte Karten", unionFrame(of: playedCards.allElementsBoundByIndex)),
            ("Mitspieler", unionFrame(of: opponentPortraits.allElementsBoundByIndex + [advance])),
            ("Handkarten", unionFrame(of: handCards.allElementsBoundByIndex))
        ]

        for region in regions {
            XCTAssertTrue(window.frame.contains(region.frame),
                          "Jede Landscape-Zone muss vollständig im Fenster liegen: \(region.name).")
            XCTAssertGreaterThan(region.frame.width, 40)
            XCTAssertGreaterThan(region.frame.height, 40)
        }

        for firstIndex in regions.indices {
            for secondIndex in regions.indices where secondIndex > firstIndex {
                let first = regions[firstIndex]
                let second = regions[secondIndex]
                XCTAssertFalse(
                    first.frame.insetBy(dx: -2, dy: -2).intersects(second.frame),
                    "Die Landscape-Zonen \(first.name) und \(second.name) dürfen sich nicht berühren."
                )
            }
        }

        XCTAssertTrue(advance.isHittable)
        XCTAssertTrue(regions[2].frame.contains(advance.frame),
                      "Die Bestätigung gehört im Querformat zum handelnden Gegner.")
        assertAdvance(advance, isAnchoredToItsNamedOpponentIn: app)

        let cards = handCards.allElementsBoundByIndex
        XCTAssertGreaterThan(cards.count, 1)
        for card in cards {
            XCTAssertTrue(window.frame.intersects(card.frame))
            XCTAssertFalse(card.frame.intersects(regions[0].frame))
            XCTAssertFalse(card.frame.intersects(regions[2].frame))
        }

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "guided-playout-compact-landscape-667x375"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testGuidedOpeningKeepsCopyPeopleAndCardsSeparateAtAccessibilityXXXLInAllLocales() {
        XCUIDevice.shared.orientation = .portrait
        let configurations = [
            ("de", "de_DE"),
            ("en", "en_US"),
            ("es", "es_ES"),
            ("fr", "fr_FR"),
            ("it", "it_IT"),
            ("nl", "nl_NL"),
            ("pl", "pl_PL")
        ]

        for configuration in configurations {
            let app = launchGuidedPlayout(
                reduceMotion: true,
                language: configuration.0,
                locale: configuration.1,
                contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
            )
            openPlayoutCurtain(in: app)

            let window = app.windows.firstMatch
            let panel = app.descendants(matching: .any)["phase3.guided.explanation"]
            let opponentPortraits = app.images.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "phase3.opponent.")
            )
            let cardQuery = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
            )

            XCTAssertTrue(panel.waitForExistence(timeout: 6), configuration.0)
            XCTAssertTrue(opponentPortraits.firstMatch.waitForExistence(timeout: 6), configuration.0)
            XCTAssertTrue(cardQuery.firstMatch.waitForExistence(timeout: 6), configuration.0)
            let cards = cardQuery.allElementsBoundByIndex
            let opponentFrame = unionFrame(of: opponentPortraits.allElementsBoundByIndex)
            XCTAssertGreaterThanOrEqual(cards.filter { $0.isEnabled && $0.isHittable }.count,
                                        2,
                                        configuration.0)
            XCTAssertTrue(window.frame.contains(panel.frame), configuration.0)
            XCTAssertFalse(panel.frame.intersects(opponentFrame), configuration.0)

            let handTop = cards.map(\.frame.minY).min() ?? .greatestFiniteMagnitude
            XCTAssertLessThanOrEqual(opponentFrame.maxY + 4, handTop, configuration.0)
            for card in cards {
                XCTAssertTrue(window.frame.intersects(card.frame), configuration.0)
                XCTAssertFalse(card.frame.intersects(panel.frame), configuration.0)
                XCTAssertFalse(card.frame.intersects(opponentFrame), configuration.0)
            }

            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "phase3-opening-axxxl-\(configuration.0)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
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
    func testOpponentSeatsStayFixedAcrossGuidedTurns() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchGuidedPlayout(reduceMotion: true)
        openPlayoutCurtain(in: app)
        advanceToFirstOpponentChoice(in: app)

        let seats = (1...3).map { app.images["phase3.opponent.\($0)"] }
        XCTAssertTrue(seats.allSatisfy(\.exists))
        let initialFrames = seats.map(\.frame)

        let advance = app.buttons["phase3.guided.advance"]
        advance.tap()
        let ace = app.buttons["phase3.hand.card.hearts.14"]
        XCTAssertTrue(waitUntil(timeout: 8) { ace.isEnabled && ace.isHittable })
        let framesAfterOpponent = seats.map(\.frame)
        for index in seats.indices {
            XCTAssertEqual(framesAfterOpponent[index].midX, initialFrames[index].midX,
                           accuracy: 1)
            XCTAssertEqual(framesAfterOpponent[index].midY, initialFrames[index].midY,
                           accuracy: 1)
        }

        ace.tap()
        XCTAssertTrue(waitUntil(timeout: 8) {
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
            ).allElementsBoundByIndex.filter { $0.isEnabled && $0.isHittable }.count >= 2
        })
        let framesAfterHuman = seats.map(\.frame)
        for index in seats.indices {
            XCTAssertEqual(framesAfterHuman[index].midX, initialFrames[index].midX,
                           accuracy: 1)
            XCTAssertEqual(framesAfterHuman[index].midY, initialFrames[index].midY,
                           accuracy: 1)
        }
    }

    @MainActor
    func testEmptyHandShowsPointsAndAResultAction() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchGuidedPlayout(reduceMotion: true)
        openPlayoutCurtain(in: app)

        let confirm = app.buttons["phase3.result.confirm"]
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline, !confirm.exists {
            let advance = app.buttons["phase3.guided.advance"]
            if advance.exists, advance.isEnabled, advance.isHittable {
                advance.tap()
            } else {
                let cards = app.buttons.matching(
                    NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
                )
                if let card = cards.allElementsBoundByIndex.first(where: {
                    $0.isEnabled && $0.isHittable
                }) {
                    card.tap()
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.20))
        }

        XCTAssertTrue(confirm.waitForExistence(timeout: 12),
                      "Nach der letzten Handkarte muss die Abrechnung sichtbar werden.")
        XCTAssertTrue(confirm.isEnabled && confirm.isHittable,
                      "Die Abrechnung braucht eine echte nächste Handlung.")
        XCTAssertTrue(app.staticTexts["MITTE"].exists)
        XCTAssertTrue(app.staticTexts["FÜR RESTKARTEN"].exists)
        XCTAssertTrue(app.staticTexts["GESAMT"].exists,
                      "Die Abrechnung muss die erreichten Chip-/Punktwerte zeigen.")
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

        let newLeadExplanation = app.descendants(matching: .any)
            .matching(identifier: "phase3.guided.explanation").firstMatch
        XCTAssertTrue(newLeadExplanation.waitForExistence(timeout: 8))
        XCTAssertTrue(newLeadExplanation.label.contains("Wähle jetzt eine neue Startkarte"),
                      "Nach dem Ass muss die Erklärung die neue freie Startwahl ankündigen: \(newLeadExplanation.label)")

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
        additionalArguments: [String] = [],
        language: String = "de",
        locale: String = "de_DE",
        contentSizeCategory: String = "UICTContentSizeCategoryL"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialPlayout",
            "-guidedPlayoutSeedQA=20",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", contentSizeCategory,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
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
    private func assertAdvance(
        _ advance: XCUIElement,
        isAnchoredToItsNamedOpponentIn app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let names = [1: "Hana", 2: "Noah", 3: "Jonas"]
        guard let seat = names.first(where: { advance.label.contains($0.value) })?.key else {
            XCTFail("Die Gegneraktion muss den handelnden Namen nennen: \(advance.label)",
                    file: file,
                    line: line)
            return
        }
        let target = app.images["phase3.opponent.\(seat)"]
        XCTAssertTrue(target.exists, file: file, line: line)
        XCTAssertLessThanOrEqual(abs(advance.frame.midX - target.frame.midX), 24,
                                 "Die Aktion muss horizontal am richtigen Avatar verankert sein.",
                                 file: file,
                                 line: line)
        XCTAssertLessThanOrEqual(advance.frame.maxY, target.frame.minY + 8,
                                 "Die Aktion muss unmittelbar oberhalb des richtigen Avatars stehen.",
                                 file: file,
                                 line: line)
        XCTAssertLessThanOrEqual(target.frame.minY - advance.frame.maxY, 12,
                                 "Zwischen Aktion und Avatar darf keine unklare räumliche Lücke entstehen.",
                                 file: file,
                                 line: line)
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
    private func unionFrame(of elements: [XCUIElement]) -> CGRect {
        elements.reduce(into: CGRect.null) { partial, element in
            partial = partial.union(element.frame)
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
