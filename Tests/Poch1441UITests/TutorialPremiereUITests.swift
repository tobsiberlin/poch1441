import XCTest

final class TutorialPremiereUITests: XCTestCase {
    @MainActor
    func testPhaseCurtainBlocksTableUntilItsOwnActionIsConfirmed() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-tutorialSeed",
            "-skipBoardTourQA",
            "-reduceMotionQA",
            "-players=4",
            "-sound", "false",
            "-haptics", "false",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()

        let curtain = app.buttons["tutorial.phaseCurtain.continue"]
        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(curtain.waitForExistence(timeout: 6))
        XCTAssertTrue(openingToken.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["chrome.settings"].exists,
                       "Während des Phasenübergangs darf keine zweite Navigationsebene sichtbar sein.")
        XCTAssertFalse(app.buttons["chrome.pause"].exists,
                       "Während des Phasenübergangs darf Pause nicht über der Übergabe schweben.")
        attachCurrentFrame(in: app, named: "tutorial-phase-curtain")

        // SwiftUI kann verdeckte Accessibility-Nodes weiterhin als bedienbar
        // melden. Ein semantischer `tap()` würde das verdeckte Element jedoch
        // direkt adressieren; der rohe Bildschirmtap prüft stattdessen den
        // tatsächlichen Vollflächenvorhang.
        let tokenFrame = openingToken.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: tokenFrame.midX, dy: tokenFrame.midY))
            .tap()
        XCTAssertTrue(curtain.exists,
                      "Die Phasenblende muss den versuchten Tisch-Tap abfangen.")
        XCTAssertTrue(openingToken.exists,
                      "Der erste Chip darf unter der Blende noch nicht gesetzt werden.")

        curtain.tap()
        XCTAssertFalse(curtain.waitForExistence(timeout: 2))
        XCTAssertTrue(openingToken.waitForExistence(timeout: 3))
        XCTAssertTrue(openingToken.isHittable,
                      "Nach der bewussten Übergabe muss der erste Spielzug erreichbar sein.")
        openingToken.tap()
        XCTAssertFalse(openingToken.waitForExistence(timeout: 2),
                       "Nach der Bestätigung muss derselbe Tisch-Tap den Zug ausführen.")
    }

    @MainActor
    func testPhaseCurtainReflowsAtAccessibilityXXXLInPortraitAndLandscape() {
        for configuration in [(name: "portrait", flag: "-portraitQA", size: CGSize(width: 375, height: 667)),
                              (name: "landscape", flag: "-landscapeQA", size: CGSize(width: 667, height: 375))] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-tutorialSeed", "-skipBoardTourQA", "-reduceMotionQA", "-players=4",
                "-sound", "false", "-haptics", "false", configuration.flag,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"
            ]
            app.launch()
            let window = app.windows.firstMatch
            let phase = app.staticTexts["1 VON 3"]
            let title = app.staticTexts["TRUMPF ZEIGEN"]
            let subtitle = app.staticTexts["Passende Trumpfkarten bringen dir sofort die Chips aus ihren Bonusfeldern."]
            let action = app.buttons["tutorial.phaseCurtain.continue"]
            XCTAssertTrue(window.waitForExistence(timeout: 4))
            XCTAssertEqual(window.frame.size, configuration.size)
            XCTAssertTrue(phase.waitForExistence(timeout: 5))
            XCTAssertTrue(title.waitForExistence(timeout: 3))
            XCTAssertTrue(subtitle.waitForExistence(timeout: 3))
            XCTAssertTrue(action.waitForExistence(timeout: 3))
            XCTAssertFalse(phase.frame.intersects(title.frame))
            XCTAssertFalse(title.frame.intersects(subtitle.frame))
            XCTAssertFalse(subtitle.frame.intersects(action.frame))
            let scroll = app.scrollViews["tutorial.phaseCurtain.scroll"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 2))
            for _ in 0..<12 where !action.isHittable || !window.frame.contains(action.frame) {
                scroll.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(action.isHittable,
                          "Die bestätigende Aktion muss im AX-Scrollpfad bedienbar bleiben.")
            XCTAssertTrue(window.frame.contains(action.frame),
                          "Die bestätigende Aktion muss vollständig ins AX-Fenster gescrollt werden können.")
            let actionLabel = app.staticTexts["Trumpf zeigen"]
            XCTAssertTrue(actionLabel.waitForExistence(timeout: 2))
            XCTAssertTrue(action.frame.contains(actionLabel.frame),
                          "Der CTA-Text darf die goldene Aktionsfläche nicht verlassen.")
            attachCurrentFrame(in: app,
                               named: "tutorial-phase-curtain-ax-\(configuration.name)")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

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
        let phaseCurtain = app.buttons["tutorial.phaseCurtain.continue"]
        if phaseCurtain.waitForExistence(timeout: 3) {
            phaseCurtain.tap()
        }

        let target = app.descendants(matching: .any)["firstRun.meldTargetCard"]
        XCTAssertTrue(target.waitForExistence(timeout: 12))
        XCTAssertEqual(target.label, "K ♦")
        XCTAssertFalse(app.descendants(matching: .any)["phase1.hand.card.diamonds.13"].exists,
                       "Die markierte Karte darf nicht zugleich als unmarkierte Handkarte erscheinen.")
        let hand = app.otherElements["firstRun.learningHand"]
        XCTAssertTrue(hand.waitForExistence(timeout: 2))
        XCTAssertTrue(hand.frame.intersects(target.frame),
                      "Die Markierung muss auf einer realen Karte in der sichtbaren Hand liegen.")

        XCTAssertTrue(app.descendants(matching: .any)["firstRun.learningState"]
            .waitForExistence(timeout: 2))
        let coachAction = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(coachAction.waitForExistence(timeout: 2))
        XCTAssertEqual(coachAction.label, "Karo-König zeigen")
        coachAction.tap()
        let nextAction = app.buttons["firstRun.coachAction"]
        let advanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Gewinn einsammeln"),
            object: nextAction
        )
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 2), .completed,
                       "Karo-König zeigen muss sichtbar zur Auszahlung weiterführen.")
        let updatedState = app.descendants(matching: .any)["firstRun.learningState"]
        XCTAssertEqual(updatedState.value as? String, "ERGEBNIS")
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

        let status = app.descendants(matching: .any)["phase3.guided.explanation"]
        XCTAssertTrue(status.waitForExistence(timeout: 8))

        let jack = app.buttons["phase3.hand.card.hearts.11"]
        XCTAssertTrue(jack.waitForExistence(timeout: 8))
        XCTAssertTrue(jack.isEnabled && jack.isHittable)
        jack.tap()
        let queen = app.buttons["phase3.hand.card.hearts.12"]
        XCTAssertTrue(queen.waitForExistence(timeout: 8))
        XCTAssertTrue(queen.isEnabled && queen.isHittable)
        queen.tap()

        let playedQueen = app.descendants(matching: .any)["phase3.played.card.hearts.12"].firstMatch
        XCTAssertTrue(playedQueen.waitForExistence(timeout: 4))
        XCTAssertFalse(status.frame.intersects(playedQueen.frame),
                       "Die Anfänger-Erklärung darf die ausgespielte Kartenreihe nicht überdecken.")
        XCTAssertLessThanOrEqual(status.frame.maxY + 8, playedQueen.frame.minY,
                                 "Zwischen Erklärung und ausgespielter Reihe braucht es sichtbar Luft.")
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
        dismissTutorialCurtainIfNeeded(in: app)

        let window = app.windows.firstMatch
        let board = app.images.matching(identifier: "table.world.phase2.board").firstMatch
        let decision = app.otherElements["phase2.decision"]
        let title = app.staticTexts["phase2.guided.title"]
        let body = app.staticTexts["phase2.guided.body"]
        let action = app.buttons["phase2.guided.prelude.action"]
        let trumpCard = app.otherElements["phase2.trump.card"]
        let comboBadge = app.staticTexts["phase2.hand.combo"]
        let comboCards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase2.hand.combo.card.")
        )

        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(board.waitForExistence(timeout: 8))
        XCTAssertTrue(decision.waitForExistence(timeout: 4))
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(body.waitForExistence(timeout: 4))
        XCTAssertTrue(action.waitForExistence(timeout: 4))
        XCTAssertTrue(trumpCard.waitForExistence(timeout: 4))
        XCTAssertTrue(comboBadge.waitForExistence(timeout: 4))
        XCTAssertEqual(title.label, "Zwei Zehner: Du darfst pochen.")
        XCTAssertTrue(body.label.contains("Ein Drilling schlägt jedes Paar"))
        XCTAssertEqual(action.label, "Einsatz wählen")
        XCTAssertTrue(action.isHittable)
        XCTAssertGreaterThanOrEqual(trumpCard.frame.width, 42,
                                    "Trumpf muss als echte, lesbare Karte am Tisch stehen.")
        XCTAssertGreaterThanOrEqual(trumpCard.frame.height, 56,
                                    "Trumpf darf nicht zu einer HUD-Marke schrumpfen.")
        XCTAssertGreaterThanOrEqual(comboCards.count, 2,
                                    "Die konkrete Poch-Gruppe muss direkt in der Hand markiert sein.")
        XCTAssertFalse(title.frame.intersects(body.frame),
                       "Titel und Anfänger-Erklärung dürfen sich nicht überlagern.")
        XCTAssertFalse(body.frame.intersects(action.frame),
                       "Erklärung und nächste Aktion dürfen sich nicht überlagern.")
        XCTAssertTrue(window.frame.contains(title.frame))
        XCTAssertTrue(window.frame.contains(body.frame))
        XCTAssertTrue(window.frame.contains(action.frame),
                      "Das Aktionsfeld \(action.frame) muss vollständig im SE-Fenster \(window.frame) liegen.")
        XCTAssertLessThan(abs(board.frame.midX - window.frame.midX), 8,
                          "Das Poch-Brett muss im geführten Hochformat die visuelle Mitte halten.")
        XCTAssertGreaterThanOrEqual(board.frame.width, window.frame.width * 0.54,
                                    "Das Poch-Brett darf im Tutorial nicht wie ein untergeordnetes Status-Icon wirken.")
        XCTAssertGreaterThanOrEqual(decision.frame.minY - board.frame.maxY, 20,
                                    "Zwischen Poch-Brett und Erklärung braucht es sichtbar Luft.")
        attachCurrentFrame(in: app, named: "tutorial-phase2-guided-402")
    }

    @MainActor
    func testGuidedBiddingCompactPortraitAndLandscapeKeepZonesSeparate() {
        for configuration in [(name: "portrait", flag: "-portraitQA", size: CGSize(width: 375, height: 667)),
                              (name: "landscape", flag: "-landscapeQA", size: CGSize(width: 667, height: 375))] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-tutorialBidding", "-tutorialBiddingStep=0", "-reduceMotionQA",
                "-players=4", "-sound", "false", "-haptics", "false",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
                configuration.flag, "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"
            ]
            app.launch()
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 5))
            XCTAssertEqual(window.frame.size, configuration.size,
                           "Der kompakte Poch-Gate muss die exakte SE-Geometrie prüfen.")
            dismissTutorialCurtainIfNeeded(in: app)

            let board = app.descendants(matching: .any)["table.world.phase2.board"].firstMatch
            let decision = app.otherElements["phase2.decision"]
            let hand = app.otherElements["phase2.hand"]
            let prelude = app.buttons["phase2.guided.prelude.action"]
            XCTAssertTrue(board.waitForExistence(timeout: 8))
            XCTAssertTrue(decision.waitForExistence(timeout: 8))
            XCTAssertTrue(hand.waitForExistence(timeout: 4))
            XCTAssertTrue(prelude.waitForExistence(timeout: 4))
            attachCurrentFrame(in: app,
                               named: "tutorial-phase2-compact-\(configuration.name)-prelude")
            XCTAssertTrue(prelude.isHittable,
                          "Der erste Poch-Schritt muss direkt bedienbar sein. Aktion: \(prelude.frame)")
            XCTAssertTrue(window.frame.contains(prelude.frame),
                          "Der erste Poch-Schritt muss im Fenster liegen. Aktion: \(prelude.frame), Fenster: \(window.frame)")
            XCTAssertTrue(window.frame.contains(board.frame),
                          "Das Poch-Brett muss vollständig im Fenster liegen. Brett: \(board.frame), Fenster: \(window.frame)")
            XCTAssertGreaterThanOrEqual(board.frame.width, 190)
            XCTAssertFalse(board.frame.intersects(decision.frame),
                           "Brett und Erklärung brauchen getrennte Zonen. Brett: \(board.frame), Erklärung: \(decision.frame)")
            XCTAssertTrue(decision.frame.contains(prelude.frame))

            prelude.tap()
            let safeStake = app.buttons["phase2.guided.stake.1"]
            let boldStake = app.buttons["phase2.guided.stake.2"]
            XCTAssertTrue(safeStake.waitForExistence(timeout: 3))
            XCTAssertTrue(boldStake.waitForExistence(timeout: 3))
            XCTAssertTrue(safeStake.isHittable)
            XCTAssertTrue(boldStake.isHittable)
            XCTAssertTrue(decision.frame.contains(safeStake.frame))
            XCTAssertTrue(decision.frame.contains(boldStake.frame))

            safeStake.tap()
            let actions = app.otherElements["phase2.actions"]
            XCTAssertTrue(actions.waitForExistence(timeout: 4))

            XCTAssertFalse(decision.frame.intersects(actions.frame),
                           "Poch-Erklärung und Aktionen dürfen sich in \(configuration.name) nicht überlagern.")
            XCTAssertFalse(actions.frame.intersects(hand.frame),
                           "Poch-Aktionen und Hand dürfen sich in \(configuration.name) nicht überlagern.")
            XCTAssertFalse(decision.frame.intersects(hand.frame),
                           "Poch-Erklärung und Hand brauchen in \(configuration.name) eigene Flächen.")
            XCTAssertTrue(window.frame.contains(actions.frame))
            XCTAssertTrue(app.buttons["phase2.action.open"].isHittable)
            let visibleHand = hand.frame.intersection(window.frame)
            XCTAssertGreaterThanOrEqual(visibleHand.height, hand.frame.height * 0.18,
                                        "Die eigene Hand muss als Spielkontext sichtbar bleiben.")

            let raise = app.buttons["phase2.action.raise"]
            if raise.exists {
                XCTAssertFalse(raise.label.contains("…"),
                               "Die Erhöhen-Aktion muss vollständig lesbar bleiben.")
            }
            attachCurrentFrame(in: app,
                               named: "tutorial-phase2-compact-\(configuration.name)")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
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
        dismissTutorialCurtainIfNeeded(in: app)

        let window = app.windows.firstMatch
        let board = app.descendants(matching: .any)["table.world.phase2.board"]
        let decision = app.otherElements["phase2.decision"]
        let title = app.staticTexts["phase2.guided.title"]
        let body = app.staticTexts["phase2.guided.body"]
        let action = app.buttons["phase2.guided.prelude.action"]
        let scroll = app.scrollViews["phase2.accessibility.scroll"]

        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(board.waitForExistence(timeout: 8))
        XCTAssertTrue(decision.waitForExistence(timeout: 4))
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(body.waitForExistence(timeout: 4))
        XCTAssertTrue(action.waitForExistence(timeout: 4))
        XCTAssertEqual(title.label, "Zwei Zehner: Du darfst pochen.")
        XCTAssertEqual(body.label, "Mit gleichen Karten darfst du pochen.")
        XCTAssertEqual(action.label, "Einsatz wählen")
        XCTAssertFalse(title.frame.intersects(body.frame))
        XCTAssertTrue(window.frame.contains(title.frame))
        XCTAssertGreaterThan(title.frame.height, 40,
                             "Accessibility XXXL muss den Tutorialtitel sichtbar vergrößern.")
        XCTAssertGreaterThan(body.frame.height, 40,
                             "Accessibility XXXL darf die Regelerklärung nicht auf Standardgröße deckeln.")
        XCTAssertGreaterThan(decision.frame.minY, board.frame.midY,
                             "Auch bei Accessibility XXXL muss die Erklärung unter dem Brett beginnen.")
        XCTAssertTrue(scroll.exists,
                      "Sehr große Schrift braucht einen klaren vertikalen Scrollpfad statt gequetschter Inhalte.")
        XCTAssertGreaterThanOrEqual(body.frame.minX, window.frame.minX)
        XCTAssertLessThanOrEqual(body.frame.maxX, window.frame.maxX,
                                 "Der große Regeltext darf horizontal nicht abgeschnitten werden.")
        for _ in 0..<6 where !action.isHittable || !window.frame.contains(action.frame) {
            scroll.swipeUp()
        }
        XCTAssertTrue(action.isHittable)
        XCTAssertTrue(window.frame.contains(action.frame),
                      "Die AX-Aktion \(action.frame) muss vollständig erreichbar sein.")
        XCTAssertGreaterThanOrEqual(action.frame.height, 52,
                                    "Die nächste Aktion braucht bei Accessibility XXXL eine vergrößerte Trefferfläche.")
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

        dismissTutorialCurtainIfNeeded(in: app)
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
        assertReadableShowdownCards(in: app)
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

        let prelude = app.buttons["firstRun.timeSwipe.prelude.primary"]
        XCTAssertTrue(prelude.waitForExistence(timeout: 4))
        XCTAssertEqual(prelude.label, "Geschichte entdecken")
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "prelude")
        prelude.tap()

        if reducedMotion {
            let next = app.buttons["firstRun.timeSwipe.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 4))
            next.tap()
            next.tap()
        } else {
            let stage = app.otherElements["firstRun.timeSwipe.stage"]
            XCTAssertTrue(stage.waitForExistence(timeout: 4))
            stage.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.28))
                .press(forDuration: 0.05,
                       thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.96,
                                                                                   dy: 0.28)))
        }

        let intro = app.buttons["firstRun.intro.primary"]
        let skipIntro = app.buttons["firstRun.intro.secondary"]
        XCTAssertTrue(intro.waitForExistence(timeout: 4))
        XCTAssertTrue(skipIntro.waitForExistence(timeout: 2))
        XCTAssertEqual(intro.label, "An den Tisch")
        XCTAssertTrue(window.frame.contains(skipIntro.frame),
                      "Auch der freie Einstieg muss ohne Scrollen vollständig sichtbar sein.")
        XCTAssertFalse(intro.frame.intersects(skipIntro.frame))
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "intro")
        intro.tap()

        let boardTourNext = app.buttons["firstRun.boardTour.next"]
        for step in 1...3 {
            XCTAssertTrue(boardTourNext.waitForExistence(timeout: 5),
                          "Kameraeinstellung \(step) muss bis zur Bestätigung stehen bleiben.")
            attachFilmFrame(in: app,
                            reducedMotion: reducedMotion,
                            moment: "board-tour-\(step)")
            boardTourNext.tap()
        }

        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4))
        openingToken.tap()

        let skipMontage = app.buttons["firstRun.montage.skip"]
        if skipMontage.waitForExistence(timeout: 3), skipMontage.isHittable {
            skipMontage.tap()
        }

        let coachAction = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(coachAction.waitForExistence(timeout: 15))
        XCTAssertEqual(coachAction.label, "Tischkarte aufdecken")
        coachAction.tap()

        let meldTarget = app.descendants(matching: .any)["firstRun.meldTargetCard"]
        XCTAssertTrue(meldTarget.waitForExistence(timeout: 5))
        XCTAssertTrue(coachAction.waitForExistence(timeout: 5))
        XCTAssertEqual(coachAction.label, "Karo-König zeigen")
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "meld-match")
        coachAction.tap()

        XCTAssertTrue(coachAction.waitForExistence(timeout: 12))
        XCTAssertEqual(coachAction.label, "Gewinn einsammeln")
        coachAction.tap()

        XCTAssertTrue(coachAction.waitForExistence(timeout: 12))
        XCTAssertEqual(coachAction.label, "Jetzt pochen")
        coachAction.tap()

        confirmPhaseCurtain("Zum Poch-Pott", in: app)

        let showStake = app.buttons["phase2.guided.prelude.action"]
        XCTAssertTrue(showStake.waitForExistence(timeout: 12))
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "poch-entry")
        advanceBiddingPrelude(in: app)
        let open = app.buttons["phase2.action.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 12),
                      "Nach der erklärten Chipwahl muss Akt 2 die echte Einsatzentscheidung anbieten.")
        XCTAssertTrue(open.isHittable)
        open.tap()

        finishBiddingWhenTheTutorialReturnsControl(to: app)

        assertReadableShowdownCards(in: app)
        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "showdown")

        let continueToPlayout = app.buttons["phase2.continue"]
        XCTAssertTrue(continueToPlayout.waitForExistence(timeout: 20))
        XCTAssertTrue(continueToPlayout.isEnabled)
        XCTAssertTrue(continueToPlayout.isHittable)
        continueToPlayout.tap()

        confirmPhaseCurtain("Erste Reihe starten", in: app)

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
        XCTAssertFalse(app.buttons["Runde abschließen"].exists,
                       "Nach der Bestätigung darf das Rundenergebnis nicht unter dem Abschluss erreichbar bleiben.")

        attachFilmFrame(in: app, reducedMotion: reducedMotion, moment: "completion")
    }

    @MainActor
    private func assertReadableShowdownCards(in app: XCUIApplication) {
        let showdown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                        "Showdown", "schlägt", "schlagen")
        ).firstMatch
        XCTAssertTrue(showdown.waitForExistence(timeout: 8),
                      "Die Lernrunde muss ihren echten Showdown sichtbar erklären.")
        let showdownCards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@",
                        "phase2.showdown.", ".card.")
        )
        XCTAssertGreaterThanOrEqual(showdownCards.count, 4,
                                    "Der Showdown muss echte Karten beider verbleibender Gruppen zeigen.")
        for index in 0..<showdownCards.count {
            let card = showdownCards.element(boundBy: index)
            XCTAssertGreaterThanOrEqual(card.frame.width, 38,
                                        "Showdownkarten müssen aus normalem Leseabstand erkennbar sein.")
            XCTAssertGreaterThanOrEqual(card.frame.height, 54,
                                        "Showdownkarten müssen mindestens 38 x 54 pt groß sein.")
        }
    }

    @MainActor
    private func advanceBiddingPrelude(in app: XCUIApplication) {
        let showStake = app.buttons["phase2.guided.prelude.action"]
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
        let button = app.buttons["tutorial.phaseCurtain.continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 8),
                      "Der Phasenwechsel muss lesbar stehen bleiben, bis er bestätigt wird.")
        XCTAssertEqual(button.label, label)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    @MainActor
    private func dismissTutorialCurtainIfNeeded(in app: XCUIApplication) {
        let curtain = app.buttons["tutorial.phaseCurtain.continue"]
        guard curtain.waitForExistence(timeout: 3) else { return }
        let scroll = app.scrollViews["tutorial.phaseCurtain.scroll"]
        for _ in 0..<5 where !curtain.isHittable {
            if scroll.exists { scroll.swipeUp() }
        }
        XCTAssertTrue(waitUntil(timeout: 2, condition: { curtain.isHittable }),
                      "Die Phasenblende muss auch mit sehr großer Schrift bestätigbar sein.")
        guard curtain.isHittable else { return }
        curtain.tap()
        XCTAssertFalse(curtain.waitForExistence(timeout: 3),
                       "Die bestätigte Phasenblende muss den Tisch vollständig freigeben.")
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
            // The table-world identifier belongs to the containing stage and is
            // intentionally inherited by SwiftUI's accessibility container.
            // Address the localized CTA by its visible contract here.
            let confirmResult = app.buttons["Runde abschließen"]
            if confirmResult.exists,
               confirmResult.isEnabled,
               confirmResult.isHittable {
                XCTAssertEqual(confirmResult.label, "Runde abschließen",
                               "Der CTA bestätigt zuerst das sichtbare Ergebnis und verspricht nicht vorzeitig eine neue Runde.")
                XCTAssertFalse(completion.exists,
                               "Tutorial-Abschluss darf das Rundenergebnis nicht überdecken")
                attachCurrentFrame(in: app, named: "tutorial-premiere-result-hold-390x844")
                RunLoop.current.run(until: Date().addingTimeInterval(1.2))
                XCTAssertTrue(confirmResult.exists && confirmResult.isHittable,
                              "Das Ergebnis muss ohne Zeitautomatik bis zur bewussten Bestätigung stehen bleiben.")
                XCTAssertFalse(completion.exists,
                               "Auch nach einer Lesepause darf der Abschluss nicht automatisch erscheinen.")
                confirmResult.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.45))
                continue
            }

            let revealNextCard = app.buttons["phase3.guided.advance"]
            if revealNextCard.exists,
               revealNextCard.isEnabled,
               revealNextCard.isHittable {
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

    @MainActor
    private func attachCurrentFrame(in app: XCUIApplication, named name: String) {
        app.activate()
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
