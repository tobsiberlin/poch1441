import XCTest

final class TutorialPremiereUITests: XCTestCase {
    @MainActor
    func testTutorialCompletionOwnsTheScreenWithoutTextOrChromeOverlap() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialComplete",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let window = app.windows.firstMatch
        let completion = app.descendants(matching: .any)["tutorial.completion"]
        let rematch = app.buttons["Noch eine Runde"]

        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(completion.waitForExistence(timeout: 6))
        XCTAssertTrue(rematch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["firstRun.coach"].exists,
                       "Unter dem Abschluss darf keine zweite Coach-Karte stehen.")
        XCTAssertFalse(app.buttons["chrome.settings"].exists,
                       "Der Abschluss blendet die Tisch-Navigation vollständig aus.")
        XCTAssertFalse(app.buttons["chrome.pause"].exists,
                       "Der Abschluss blendet die Tisch-Navigation vollständig aus.")
        XCTAssertTrue(window.frame.contains(completion.frame),
                      "Die Abschlusskarte muss vollständig im sichtbaren Display liegen.")
        XCTAssertTrue(completion.frame.contains(rematch.frame))
        XCTAssertFalse(app.buttons["Spielzüge ansehen"].exists,
                       "Der Abschluss braucht genau eine klare Revanche-Aktion.")
    }

    @MainActor
    func testMarkedMeldCardTargetsTheRealCardInsteadOfEmptySpace() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialMeldStep=5",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let target = app.buttons["firstRun.meldMatch"]
        XCTAssertTrue(target.waitForExistence(timeout: 12))
        XCTAssertTrue(target.isHittable)
        XCTAssertEqual(target.label, "Trumpf-König melden")
        XCTAssertFalse(app.descendants(matching: .any)["phase1.hand.card.diamonds.13"].exists,
                       "Die markierte Karte darf unter dem gleich großen VoiceOver-Ziel kein zweites Element bilden.")

        target.tap()
        XCTAssertFalse(target.waitForExistence(timeout: 2),
                       "Ein Tipp auf die markierte Karte muss den Schritt sichtbar abschließen.")
    }

    @MainActor
    func testPlayoutExplanationStaysClearOfTheCenterPot() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialPlayout",
            "-guidedPlayoutSeedQA=20",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let phase = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase.waitForExistence(timeout: 8))
        let curtain = app.buttons["tutorial.phaseCurtain.continue"]
        if curtain.waitForExistence(timeout: 3), curtain.isHittable {
            curtain.tap()
        }

        let status = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "DEINE ERSTE REIHE")
        ).firstMatch
        let center = app.descendants(matching: .any)["Poch-Medaillon"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertTrue(center.waitForExistence(timeout: 4))
        XCTAssertFalse(status.frame.intersects(center.frame),
                       "Die Anfänger-Erklärung darf den großen Mittel-Topf nicht überdecken.")
        XCTAssertLessThanOrEqual(status.frame.maxY + 8, center.frame.minY,
                                 "Zwischen Erklärung und Mittel-Topf braucht es sichtbar Luft.")
    }

    @MainActor
    func testBiddingTutorialCopyAndActionStayReadable() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialBidding",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let window = app.windows.firstMatch
        let title = app.staticTexts["Deine Karten öffnen den Poch"]
        let body = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "damit darfst du pochen")
        ).firstMatch
        let action = app.buttons["Einsatz wählen"]

        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(body.waitForExistence(timeout: 4))
        XCTAssertTrue(action.waitForExistence(timeout: 4))
        XCTAssertTrue(action.isHittable)
        XCTAssertFalse(title.frame.intersects(body.frame),
                       "Titel und Anfänger-Erklärung dürfen sich nicht überlagern.")
        XCTAssertFalse(body.frame.intersects(action.frame),
                       "Erklärung und nächste Aktion dürfen sich nicht überlagern.")
        XCTAssertTrue(window.frame.contains(title.frame))
        XCTAssertTrue(window.frame.contains(body.frame))
        XCTAssertTrue(window.frame.contains(action.frame))
    }

    @MainActor
    func testBiddingTutorialCopyReflowsAtAccessibilityXXXL() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialBidding",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let window = app.windows.firstMatch
        let title = app.staticTexts["Deine Karten öffnen den Poch"]
        let body = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "damit darfst du pochen")
        ).firstMatch
        let action = app.buttons["Einsatz wählen"]

        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(body.waitForExistence(timeout: 4))
        XCTAssertTrue(action.waitForExistence(timeout: 4))
        XCTAssertTrue(action.isHittable)
        XCTAssertFalse(title.frame.intersects(body.frame))
        XCTAssertFalse(body.frame.intersects(action.frame))
        XCTAssertTrue(window.frame.contains(title.frame))
        XCTAssertTrue(window.frame.contains(body.frame))
        XCTAssertTrue(window.frame.contains(action.frame))
        XCTAssertGreaterThan(title.frame.height, 20,
                             "Accessibility XXXL muss den Tutorialtitel sichtbar vergrößern.")
    }

    @MainActor
    func testGuidedDealCardsArriveAndPersistAtEveryOpponent() {
        XCUIDevice.shared.orientation = .portrait
        let partialApp = launchGuidedMeldState(step: 3)
        let partialCounts = guidedOpponentDealCounts(in: partialApp)
        XCTAssertTrue(partialCounts.allSatisfy { $0 > 0 },
                      "Nach der ersten Austeilrunde muss bei jedem Mitspieler eine Karte liegen.")
        partialApp.terminate()

        let completedApp = launchGuidedMeldState(step: 4)
        let completedCounts = guidedOpponentDealCounts(in: completedApp)
        for index in partialCounts.indices {
            XCTAssertGreaterThan(completedCounts[index], partialCounts[index],
                                 "Jeder Kartenfächer muss bis zur vollständigen Hand sichtbar anwachsen.")
        }
        completedApp.terminate()

        let trumpApp = launchGuidedMeldState(step: 5)
        let persistedCounts = guidedOpponentDealCounts(in: trumpApp)
        XCTAssertEqual(persistedCounts, completedCounts,
                       "Beim Trumpf-Aufdecken dürfen fertige Kartenfächer nicht verschwinden.")
    }

    @MainActor
    func testFilmTutorialFirstJourneyAt390x844() throws {
        try runFilmTutorial(reducedMotion: false)
    }

    @MainActor
    func testFilmTutorialFirstJourneyWithReducedMotionAt390x844() throws {
        try runFilmTutorial(reducedMotion: true)
    }

    @MainActor
    func testSingleBiddingLessonStopsBeforePlayout() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialBidding",
            "-resetTutorialProgressQA",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        advanceBiddingPrelude(in: app)
        let open = app.buttons["phase2.action.open"]
        let pass = app.buttons["phase2.action.pass"]
        XCTAssertTrue(open.waitForExistence(timeout: 12) || pass.waitForExistence(timeout: 2))
        if open.exists, open.isHittable {
            open.tap()
        } else {
            pass.tap()
        }

        finishBiddingWhenTheTutorialReturnsControl(to: app)
        let continueButton = app.buttons["phase2.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 20))
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let completion = app.descendants(matching: .any)["tutorial.completion"]
        XCTAssertTrue(completion.waitForExistence(timeout: 6))
        XCTAssertEqual(completion.value as? String, "1/3")
        XCTAssertFalse(app.descendants(matching: .any)["table.world.phase3"].exists)
    }

    @MainActor
    private func runFilmTutorial(reducedMotion: Bool) throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        var launchArguments = [
            "-firstRun",
            "-firstRunBeat=4",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        if reducedMotion {
            launchArguments.append("-reduceMotionQA")
        }
        app.launchArguments = launchArguments
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4))
        try XCTSkipUnless(
            abs(window.frame.width - 390) <= 1 && abs(window.frame.height - 844) <= 1,
            "Dieses Film-Gate wird ausschließlich auf dem 390 × 844-Referenzgerät bewertet."
        )

        let intro = app.buttons["firstRun.intro.primary"]
        let skipIntro = app.buttons["firstRun.intro.secondary"]
        XCTAssertTrue(intro.waitForExistence(timeout: 4))
        XCTAssertTrue(skipIntro.waitForExistence(timeout: 2))
        XCTAssertEqual(intro.label, "Mitspielen")
        XCTAssertTrue(window.frame.contains(skipIntro.frame),
                      "Auch der freie Einstieg muss ohne Scrollen vollständig sichtbar sein.")
        XCTAssertFalse(intro.frame.intersects(skipIntro.frame))
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "intro")
        intro.tap()

        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4))
        openingToken.tap()

        let skipMontage = app.buttons["firstRun.montage.skip"]
        if skipMontage.waitForExistence(timeout: 3), skipMontage.isHittable {
            skipMontage.tap()
        }

        let coachAction = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(coachAction.waitForExistence(timeout: 15))
        XCTAssertEqual(coachAction.label, "Trumpf aufdecken")
        coachAction.tap()

        let meldMatch = app.buttons["firstRun.meldMatch"]
        XCTAssertTrue(meldMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(meldMatch.isEnabled)
        XCTAssertTrue(meldMatch.isHittable)
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "meld-match")
        meldMatch.tap()

        XCTAssertTrue(coachAction.waitForExistence(timeout: 12))
        XCTAssertEqual(coachAction.label, "Weiter zum Pochen")
        coachAction.tap()

        confirmPhaseCurtain("Jetzt pochen", in: app)

        let showStake = app.buttons["Einsatz wählen"]
        XCTAssertTrue(showStake.waitForExistence(timeout: 12))
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "poch-entry")
        advanceBiddingPrelude(in: app)
        let open = app.buttons["phase2.action.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 12),
                      "Nach der erklärten Chipwahl muss Akt 2 die echte Einsatzentscheidung anbieten.")
        XCTAssertTrue(open.isHittable)
        open.tap()

        finishBiddingWhenTheTutorialReturnsControl(to: app)

        let showdown = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "gewinnt den Showdown")
        ).firstMatch
        XCTAssertTrue(showdown.waitForExistence(timeout: 8),
                      "Die erste Lernreise muss ihren echten Showdown sichtbar erklären.")
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "showdown")

        let continueToPlayout = app.buttons["phase2.continue"]
        XCTAssertTrue(continueToPlayout.waitForExistence(timeout: 20))
        XCTAssertTrue(continueToPlayout.isEnabled)
        XCTAssertTrue(continueToPlayout.isHittable)
        continueToPlayout.tap()

        confirmPhaseCurtain("Karten ausspielen", in: app)

        let phase3 = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase3.waitForExistence(timeout: 6))
        let cards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        )
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10))
        let initialCardCount = cards.count
        XCTAssertGreaterThan(initialCardCount, 0)
        guard let openingCard = firstPlayableCard(in: cards) else {
            XCTFail("Die erste Ausspielkarte muss als echte, aktive Karte auffindbar sein.")
            return
        }
        XCTAssertTrue(openingCard.isHittable,
                      "Die erste Ausspielkarte muss eine eigene, verständliche Handlung sein.")
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "playout-start")

        openingCard.tap()
        let handShrank = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in cards.count < initialCardCount },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [handShrank], timeout: 8), .completed,
                       "Die selbst gewählte Karte muss die sichtbare Hand wirklich verlassen.")

        finishPlayoutUntilTutorialCompletion(in: app)
        let completion = app.descendants(matching: .any)["tutorial.completion"]
        XCTAssertTrue(completion.waitForExistence(timeout: 12),
                      "Die geführte Runde muss mit einem sichtbaren Abschluss enden.")
        XCTAssertEqual(completion.value as? String, "3/3")
        XCTAssertTrue(app.buttons["Noch eine Runde"].exists)

        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "completion")
    }

    @MainActor
    private func advanceBiddingPrelude(in app: XCUIApplication) {
        let showStake = app.buttons["Einsatz wählen"]
        XCTAssertTrue(showStake.waitForExistence(timeout: 12))
        XCTAssertTrue(showStake.isHittable)
        showStake.tap()

        let selectMinimum = app.buttons["phase2.guided.stake.1"]
        XCTAssertTrue(selectMinimum.waitForExistence(timeout: 6))
        XCTAssertTrue(selectMinimum.isHittable)
        selectMinimum.tap()
    }

    @MainActor
    private func confirmPhaseCurtain(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 8),
                      "Der Phasenwechsel muss lesbar stehen bleiben, bis er bestätigt wird.")
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    @MainActor
    private func launchGuidedMeldState(step: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialMeldStep=\(step)",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()
        return app
    }

    @MainActor
    private func guidedOpponentDealCounts(in app: XCUIApplication) -> [Int] {
        (1...3).map { seatIndex in
            let seat = app.descendants(matching: .any)["phase1.deal.seat.\(seatIndex)"]
            XCTAssertTrue(seat.waitForExistence(timeout: 8))
            if let value = seat.value as? String, let count = Int(value) {
                return count
            }
            if let value = seat.value as? NSNumber {
                return value.intValue
            }
            XCTFail("Der Kartenfächer von Sitz \(seatIndex) braucht einen lesbaren Kartenzähler.")
            return 0
        }
    }

    @MainActor
    private func finishBiddingWhenTheTutorialReturnsControl(to app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(28)
        let continueButton = app.buttons["phase2.continue"]
        let call = app.buttons["phase2.action.call"]
        let pass = app.buttons["phase2.action.pass"]

        while Date() < deadline {
            if continueButton.exists,
               continueButton.isEnabled,
               continueButton.isHittable {
                return
            }
            if call.exists, call.isHittable {
                call.tap()
            } else if pass.exists, pass.isHittable {
                pass.tap()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    @MainActor
    private func finishPlayoutUntilTutorialCompletion(in app: XCUIApplication) {
        let completion = app.descendants(matching: .any)["tutorial.completion"]
        let cards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase3.hand.card.")
        )
        let deadline = Date().addingTimeInterval(90)

        while Date() < deadline, !completion.exists {
            let guidedAdvanceLabels = [
                "Nächste Karte ansehen",
                "Hana eröffnet die nächste Reihe",
                "Noah eröffnet die nächste Reihe",
                "Jonas eröffnet die nächste Reihe"
            ]
            let revealNextCard = guidedAdvanceLabels
                .map { app.buttons[$0] }
                .first { $0.exists && $0.isEnabled && $0.isHittable }
            if let revealNextCard {
                revealNextCard.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.45))
                continue
            }

            if let card = firstPlayableCard(in: cards) {
                card.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.45))
            } else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.20))
            }
        }
    }

    @MainActor
    private func firstPlayableCard(in cards: XCUIElementQuery) -> XCUIElement? {
        cards.allElementsBoundByIndex.first { $0.isEnabled && $0.isHittable }
    }

    @MainActor
    private func attachFilmFrame(in app: XCUIApplication,
                                 reducedMotion: Bool,
                                 moment: String) {
        app.activate()
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "tutorial-premiere-\(moment)-\(reducedMotion ? "reduced-motion-" : "")390x844"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
