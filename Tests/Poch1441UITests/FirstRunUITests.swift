import XCTest

final class FirstRunUITests: XCTestCase {
    @MainActor
    func testNaturalMontageReturnsAVisibleTrumpAction() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = localizedArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])
        app.launch()

        let enterTable = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(enterTable.waitForExistence(timeout: 4))
        enterTable.tap()

        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4))
        openingToken.tap()
        dismissGuidedPhaseCurtainIfPresent(in: app)

        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 15))
        XCTAssertEqual(action.label, "Trumpf aufdecken")
        XCTAssertTrue(action.isHittable)

        let window = app.windows.firstMatch
        XCTAssertTrue(window.frame.contains(action.frame),
                      "Die nächste menschliche Aktion muss vollständig im Viewport liegen.")
        attachScreenshot(of: app, named: "natural-montage-visible-trump-action")
    }

    @MainActor
    func testFirstRunKeepsItsMeaningAcrossRotation() {
        let app = XCUIApplication()
        app.launchArguments = localizedArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])

        XCUIDevice.shared.orientation = .portrait
        app.launch()

        assertWindow(in: app, hasOrientation: .portrait)
        assertIntroContract(in: app, orientation: .portrait)
        attachScreenshot(of: app, named: "first-run-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        assertWindow(in: app, hasOrientation: .landscape)

        assertIntroContract(in: app, orientation: .landscape)
        attachScreenshot(of: app, named: "first-run-landscape")
    }

    @MainActor
    func testFirstContactAndLearningStates() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = localizedArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])
        app.launch()
        assertStableWindow(in: app,
                           hasOrientation: .portrait,
                           context: "Erster Kontakt")

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
        dismissGuidedPhaseCurtainIfPresent(in: app)

        let coach = app.otherElements["firstRun.coach"]
        guard coach.waitForExistence(timeout: 4) else {
            XCTFail("Nach dem ersten Kontakt muss die kurze Tischmontage erklärt bleiben.")
            return
        }
        XCTAssertFalse(app.buttons["firstRun.coachAction"].exists,
                       "Tischfüllung und Geben dürfen keinen passiven Weiter-Tap verlangen.")
        attachScreenshot(of: app, named: "first-contact-montage")

        let nextAction = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(nextAction.waitForExistence(timeout: 15),
                      "Nach der Montage muss Trumpf die nächste eigene Handlung sein.")
        XCTAssertEqual(nextAction.label, "Trumpf aufdecken")
        XCTAssertTrue(nextAction.isHittable,
                      "Trumpf aufdecken muss ohne Scrollen sichtbar und direkt tippbar sein.")
        assertLearningState("Dein Zug", in: app)
        assertFixedOpponents(in: app)
        attachScreenshot(of: app, named: "first-contact-montage-complete")

        let checkpoints: [(step: Int, state: String, name: String)] = [
            (3, "Dein Zug", "first-card"),
            (4, "Dein Zug", "trump-ready"),
            (5, "Dein Zug", "meld-connect"),
            (6, "Gewinn zeigen", "meld-prove"),
            (7, "Geschafft", "meld-release")
        ]

        for checkpoint in checkpoints {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
            app.launchArguments = localizedArguments([
                "-tutorialSeed",
                "-tutorialMeldStep=\(checkpoint.step)",
                "-players=4"
            ])
            app.launch()
            dismissGuidedPhaseCurtainIfPresent(in: app)
            assertStableWindow(in: app,
                               hasOrientation: .portrait,
                               context: checkpoint.name)
            assertLearningState(checkpoint.state, in: app)
            assertFixedOpponents(in: app)
            if checkpoint.step == 5 {
                let action = app.buttons["firstRun.coachAction"]
                XCTAssertTrue(action.waitForExistence(timeout: 4),
                              "Der Melde-Moment braucht neben der Karte eine eindeutige sichtbare Aktion.")
                XCTAssertEqual(action.label, "Trumpf-König melden")
                XCTAssertTrue(action.isHittable,
                              "Trumpf-König melden muss ohne Rätselstelle bedienbar sein.")
            }
            attachScreenshot(of: app, named: checkpoint.name)
        }
    }

    @MainActor
    func testFirstRunReflowsAtAccessibilityXXXLOnSmallPhone() {
        let standardApp = XCUIApplication()
        standardApp.terminate()
        XCUIDevice.shared.orientation = .portrait
        standardApp.launchArguments = standardContentSizeArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])
        standardApp.launch()
        assertWindow(in: standardApp, hasOrientation: .portrait)

        let standardTitle = standardApp.descendants(matching: .any)["firstRun.intro.title"]
        let standardBody = standardApp.descendants(matching: .any)["firstRun.intro.body"]
        XCTAssertTrue(standardTitle.waitForExistence(timeout: 4))
        XCTAssertTrue(standardBody.waitForExistence(timeout: 4))
        let standardTitleHeight = standardTitle.frame.height
        let standardBodyHeight = standardBody.frame.height
        standardApp.terminate()

        let accessibilityApp = XCUIApplication()
        accessibilityApp.launchArguments = accessibilityXXXLArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])
        accessibilityApp.launch()
        assertWindow(in: accessibilityApp, hasOrientation: .portrait)
        assertFullFirstRunActionLabels(in: accessibilityApp)

        let window = accessibilityApp.windows.firstMatch
        XCTAssertLessThanOrEqual(
            window.frame.width,
            390,
            "Dieser Gate muss auf einer kleinen iPhone-Klasse wie dem iPhone SE ausgeführt werden."
        )

        let accessibilityTitle = accessibilityApp.descendants(matching: .any)["firstRun.intro.title"]
        let accessibilityBody = accessibilityApp.descendants(matching: .any)["firstRun.intro.body"]
        XCTAssertTrue(accessibilityTitle.waitForExistence(timeout: 4))
        XCTAssertTrue(accessibilityBody.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(
            accessibilityTitle.frame.height,
            standardTitleHeight * 1.25,
            "Accessibility XXXL muss den Titel wirklich vergrößern und darf nicht nur denselben festen Frame behalten."
        )
        XCTAssertGreaterThan(
            accessibilityBody.frame.height,
            standardBodyHeight * 1.5,
            "Accessibility XXXL muss den Fließtext sichtbar vergrößern und neu umbrechen."
        )
        attachTextEvidence(
            """
            Fenster: \(window.frame)
            Titel Standard: \(standardTitleHeight) pt
            Titel Accessibility XXXL: \(accessibilityTitle.frame.height) pt
            Fließtext Standard: \(standardBodyHeight) pt
            Fließtext Accessibility XXXL: \(accessibilityBody.frame.height) pt
            """,
            named: "first-run-se-dynamic-type-frame-evidence"
        )

        assertVisibleIntroSurfacesDoNotOverlap(in: accessibilityApp, context: "Portrait oben")
        assertReachableByScrolling("firstRun.intro.primary", in: accessibilityApp)
        assertVisibleIntroSurfacesDoNotOverlap(in: accessibilityApp, context: "Portrait Primäraktion")
        assertReachableByScrolling("firstRun.intro.secondary", in: accessibilityApp)
        assertVisibleIntroSurfacesDoNotOverlap(in: accessibilityApp, context: "Portrait Sekundäraktion")
        attachScreenshot(of: accessibilityApp, named: "first-run-se-accessibility-xxxl-portrait")
        accessibilityApp.terminate()
    }

    @MainActor
    func testFirstRunAccessibilityXXXLInLandscapeOnSmallPhone() {
        let app = XCUIApplication()
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = accessibilityXXXLArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.orientation = .landscapeLeft
        assertWindow(in: app, hasOrientation: .landscape)
        XCTAssertEqual(app.state, .runningForeground, "Der Landscape-Gate darf nicht gegen SpringBoard laufen.")
        assertFullFirstRunActionLabels(in: app)

        assertVisibleIntroSurfacesDoNotOverlap(in: app, context: "Landscape oben")
        attachScreenshot(of: app, named: "first-run-se-accessibility-xxxl-landscape-top")
        assertReachableByScrolling("firstRun.intro.primary", in: app)
        assertVisibleIntroSurfacesDoNotOverlap(in: app, context: "Landscape Primäraktion")
        assertReachableByScrolling("firstRun.intro.secondary", in: app)
        assertVisibleIntroSurfacesDoNotOverlap(in: app, context: "Landscape Sekundäraktion")
        app.activate()
        assertWindow(in: app, hasOrientation: .landscape)
        attachIntroFrameEvidence(in: app, named: "first-run-se-landscape-frame-evidence")
        attachScreenshot(of: app, named: "first-run-se-accessibility-xxxl-landscape")
        app.terminate()
    }

    @MainActor
    func testLearningFlowStaysZonedAtAccessibilityXXXLInPortrait() {
        let app = XCUIApplication()
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = accessibilityXXXLArguments([
            "-tutorialSeed",
            "-tutorialMeldStep=5",
            "-players=4"
        ])
        app.launch()
        dismissGuidedPhaseCurtainIfPresent(in: app)

        assertWindow(in: app, hasOrientation: .portrait)
        assertLearningState("Dein Zug", in: app)
        assertMeldMatchIsReachable(in: app)
        assertLearningStageDoesNotOverlap(in: app, context: "XXXL Portrait")
        attachScreenshot(of: app, named: "first-run-learning-xxxl-portrait")
        app.terminate()
    }

    @MainActor
    func testLearningFlowStaysZonedAtAccessibilityXXXLInLandscape() {
        let arguments = [
            "-tutorialSeed",
            "-tutorialMeldStep=5",
            "-players=4"
        ]

        let standardApp = XCUIApplication()
        standardApp.terminate()
        XCUIDevice.shared.orientation = .portrait
        standardApp.launchArguments = standardContentSizeArguments(arguments)
        standardApp.launch()
        dismissGuidedPhaseCurtainIfPresent(in: standardApp)
        assertWindow(in: standardApp, hasOrientation: .portrait)
        assertLearningState("Dein Zug", in: standardApp)
        let standardCoachTitleHeight = learningCoachTitleHeight(in: standardApp)
        standardApp.terminate()

        let landscapeApp = XCUIApplication()
        landscapeApp.terminate()
        XCUIDevice.shared.orientation = .portrait
        landscapeApp.launchArguments = accessibilityXXXLArguments(arguments)
        landscapeApp.launch()
        dismissGuidedPhaseCurtainIfPresent(in: landscapeApp)
        assertWindow(in: landscapeApp, hasOrientation: .portrait)
        assertLearningState("Dein Zug", in: landscapeApp)
        let accessibilityCoachTitleHeight = learningCoachTitleHeight(in: landscapeApp)
        XCTAssertGreaterThan(
            accessibilityCoachTitleHeight,
            standardCoachTitleHeight * 1.10,
            "Der Gate muss eine tatsächlich skalierende AX-XXXL-Erklärung prüfen."
        )
        attachTextEvidence(
            "Coach-Titel Standard: \(standardCoachTitleHeight) pt\nCoach-Titel AX XXXL: \(accessibilityCoachTitleHeight) pt",
            named: "first-run-learning-ax-xxxl-size-proof"
        )

        rotateForegroundAppToLandscape(landscapeApp)
        assertSmallPhoneLandscapeWindow(in: landscapeApp)
        assertLearningState("Dein Zug", in: landscapeApp)
        attachLearningViewportEvidence(
            in: landscapeApp,
            named: "first-run-learning-xxxl-landscape-initial-frames"
        )
        assertInitialLandscapeLearningViewport(in: landscapeApp)
        assertLearningStageDoesNotOverlap(in: landscapeApp, context: "XXXL Landscape")
        assertLandscapeLearningContentCanBeFullyRevealed(in: landscapeApp)
        attachLearningViewportEvidence(
            in: landscapeApp,
            named: "first-run-learning-xxxl-landscape-bottom-frames"
        )
        restoreLearningStageToTop(in: landscapeApp)
        attachTextEvidence(
            "Landscape-App ist im initialen Lernframe bereit für den direkten Simulator-Capture.",
            named: "first-run-learning-xxxl-landscape-capture-ready"
        )
        Thread.sleep(forTimeInterval: 8)
    }

    @MainActor
    func testOpeningImpactSurvivesRotation() {
        let app = XCUIApplication()
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = localizedArguments(["-firstRun", "-firstRunBeat=4", "-players=4"])
        app.launch()

        let enterTable = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(enterTable.waitForExistence(timeout: 4))
        enterTable.tap()
        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4))
        openingToken.tap()
        dismissGuidedPhaseCurtainIfPresent(in: app)
        XCUIDevice.shared.orientation = .landscapeLeft

        assertWindow(in: app, hasOrientation: .landscape)
        XCTAssertTrue(
            app.buttons["firstRun.coachAction"].waitForExistence(timeout: 15),
            "Rotation während der Montage muss stabil bis zur nächsten eigenen Handlung führen."
        )
        XCTAssertEqual(app.buttons["firstRun.coachAction"].label, "Trumpf aufdecken")
        assertLearningState("Dein Zug", in: app)
        app.terminate()
    }

    @MainActor
    func testSecondaryActionStartsAFreeTableWithoutTutorialFurniture() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = localizedArguments([
            "-firstRun",
            "-firstRunBeat=4",
            "-players=4",
            "-reduceMotionQA"
        ])
        app.launch()

        let secondary = app.buttons["firstRun.intro.secondary"]
        XCTAssertTrue(secondary.waitForExistence(timeout: 4))
        XCTAssertEqual(secondary.label, "Ohne Hinweise starten")
        XCTAssertTrue(secondary.isHittable)
        secondary.tap()

        XCTAssertFalse(
            app.buttons["firstRun.openingToken"].waitForExistence(timeout: 2),
            "Die ruhige Nebenoption darf nicht versehentlich in die geführte Eröffnungsaktion führen."
        )
        XCTAssertTrue(
            app.staticTexts["MELDEN"].waitForExistence(timeout: 4),
            "Die Nebenoption muss unmittelbar am freien Tisch in Phase 1 landen."
        )
        attachScreenshot(of: app, named: "first-run-secondary-free-table")
        app.terminate()
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
    private func assertIntroContract(in app: XCUIApplication, orientation: ExpectedOrientation) {
        for (seat, opponent) in ["Hana", "Noah", "Jonas"].enumerated() {
            let portraitName = app.staticTexts
                .matching(identifier: "firstRun.cinematic.opponent.\(seat + 1)")
                .firstMatch
            XCTAssertTrue(
                portraitName.waitForExistence(timeout: 3),
                "Der feste Tutorialplatz \(opponent) muss sichtbar bleiben."
            )
            XCTAssertEqual(portraitName.label, opponent)
        }

        XCTAssertTrue(
            app.buttons.firstMatch.waitForExistence(timeout: 3),
            "Die primäre First-Run-Aktion muss erreichbar bleiben."
        )

        let windowFrame = app.windows.firstMatch.frame
        let identifiers = [
            "firstRun.intro.title",
            "firstRun.intro.body",
            "firstRun.intro.primary",
            "firstRun.intro.secondary"
        ]
        let scrollView = app.scrollViews.firstMatch

        for identifier in identifiers {
            let isAction = identifier == "firstRun.intro.primary"
                || identifier == "firstRun.intro.secondary"
            let element = isAction
                ? app.buttons[identifier]
                : app.staticTexts[identifier]
            XCTAssertTrue(element.waitForExistence(timeout: 3), "\(identifier) muss existieren.")
            if scrollView.exists {
                for _ in 0..<4 where !windowFrame.intersects(element.frame) {
                    scrollView.swipeUp()
                }
            }
            let frame = element.frame
            let isFullyVisible: Bool
            switch orientation {
            case .portrait:
                isFullyVisible = windowFrame.contains(frame)
            case .landscape:
                isFullyVisible = windowFrame.intersects(frame) && frame.height <= windowFrame.height
            }
            XCTAssertTrue(
                isFullyVisible && frame.width >= 44 && frame.height > 0,
                "\(identifier) liegt mit Frame \(frame) außerhalb von \(windowFrame)."
            )
            if isAction {
                XCTAssertTrue(element.isHittable,
                              "\(identifier) muss in \(orientation) direkt bedienbar sein.")
            }
        }

        let board = app.images.matching(identifier: "firstRun.cinematic.table").firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 3), "Die echte Poch Disc muss sichtbar bleiben.")
        switch orientation {
        case .portrait:
            XCTAssertTrue(
                windowFrame.contains(board.frame),
                "Die echte Poch Disc muss vollständig sichtbar bleiben: \(board.frame)."
            )
        case .landscape:
            XCTAssertTrue(
                windowFrame.intersects(board.frame),
                "Die echte Poch Disc muss die rechte Landscape-Zone belegen: \(board.frame)."
            )
        }
        for (seat, opponentName) in ["Hana", "Noah", "Jonas"].enumerated() {
            let opponent = app.staticTexts
                .matching(identifier: "firstRun.cinematic.opponent.\(seat + 1)")
                .firstMatch
            XCTAssertTrue(
                opponent.waitForExistence(timeout: 3)
                    && opponent.frame.width > 0
                    && opponent.frame.height > 0
                    && windowFrame.intersects(opponent.frame),
                "Der cineastische Tutorialplatz \(opponentName) muss sichtbar bleiben."
            )
            XCTAssertTrue(
                windowFrame.contains(opponent.frame),
                "Tutorialplatz \(opponentName) muss vollständig im App-Fenster liegen."
            )
        }
        assertVisibleIntroSurfacesDoNotOverlap(in: app,
                                               context: "Cinematic \(orientation)")
    }

    @MainActor
    private func assertFixedOpponents(in app: XCUIApplication) {
        let windowFrame = app.windows.firstMatch.frame
        let windowOrientation = windowFrame.height > windowFrame.width ? "Portrait" : "Landscape"
        let deviceOrientation = String(describing: XCUIDevice.shared.orientation)
        for seat in 1...3 {
            let opponent = app.descendants(matching: .any)["firstRun.opponent.\(seat)"]
            XCTAssertTrue(
                opponent.waitForExistence(timeout: 4),
                "Tutorialplatz \(seat) muss im selben semantischen Sitz sichtbar bleiben."
            )
            let opponentFrame = opponent.frame
            XCTAssertTrue(
                windowFrame.intersects(opponentFrame)
                    && opponentFrame.width >= 44
                    && opponentFrame.height >= 44,
                "Tutorialplatz \(seat) muss mit sichtbarer Porträtfläche im App-Fenster liegen. "
                    + "Gegner: \(opponentFrame), Fenster: \(windowFrame), "
                    + "Fensterausrichtung: \(windowOrientation), Geräteausrichtung: \(deviceOrientation)."
            )
        }
    }

    @MainActor
    private func assertStableWindow(in app: XCUIApplication,
                                    hasOrientation orientation: ExpectedOrientation,
                                    context: String) {
        assertWindow(in: app, hasOrientation: orientation)
        let settledFrame = app.windows.firstMatch.frame
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertEqual(
            app.windows.firstMatch.frame,
            settledFrame,
            "\(context): Das App-Fenster muss vor den Layoutassertions einen stabilen Frame halten."
        )
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
    private func assertLearningStageDoesNotOverlap(in app: XCUIApplication, context: String) {
        let board = app.descendants(matching: .any)["firstRun.learningBoard"]
        let coach = app.otherElements["firstRun.coach"]
        let hand = app.descendants(matching: .any)["firstRun.learningHand"]
        for (name, element) in [("Disc", board), ("Coach", coach), ("Hand", hand)] {
            XCTAssertTrue(element.waitForExistence(timeout: 4), "\(context): \(name) fehlt.")
            XCTAssertGreaterThan(element.frame.width, 0, "\(context): \(name) hat keinen Layoutframe.")
            XCTAssertGreaterThan(element.frame.height, 0, "\(context): \(name) hat keinen Layoutframe.")
        }
        XCTAssertFalse(board.frame.intersects(coach.frame),
                       "\(context): Disc \(board.frame) und Coach \(coach.frame) überlagern sich.")
        XCTAssertFalse(board.frame.intersects(hand.frame),
                       "\(context): Disc \(board.frame) und Hand \(hand.frame) überlagern sich.")
        XCTAssertFalse(hand.frame.intersects(coach.frame),
                       "\(context): Hand \(hand.frame) und Coach \(coach.frame) überlagern sich.")

        var opponentFrames: [(seat: Int, frame: CGRect)] = []
        for seat in 1...3 {
            let opponent = app.descendants(matching: .any)["firstRun.opponent.\(seat)"]
            XCTAssertTrue(opponent.waitForExistence(timeout: 4), "\(context): Gegnerplatz \(seat) fehlt.")
            XCTAssertGreaterThanOrEqual(opponent.frame.width, 44, "\(context): Gegnerplatz \(seat) ist zu schmal.")
            XCTAssertGreaterThanOrEqual(opponent.frame.height, 44, "\(context): Gegnerplatz \(seat) ist zu niedrig.")
            for (name, frame) in [("Disc", board.frame), ("Coach", coach.frame), ("Hand", hand.frame)] {
                XCTAssertFalse(
                    opponent.frame.intersects(frame),
                    "\(context): Gegnerplatz \(seat) \(opponent.frame) überlagert \(name) \(frame)."
                )
            }
            opponentFrames.append((seat, opponent.frame))
        }
        for firstIndex in opponentFrames.indices {
            for secondIndex in opponentFrames.indices where secondIndex > firstIndex {
                let first = opponentFrames[firstIndex]
                let second = opponentFrames[secondIndex]
                XCTAssertFalse(
                    first.frame.intersects(second.frame),
                    "\(context): Gegnerplätze \(first.seat) und \(second.seat) überlagern sich."
                )
            }
        }
    }

    @MainActor
    private func learningCoachTitleHeight(in app: XCUIApplication) -> CGFloat {
        let title = app.staticTexts["Dein Trumpf-König trifft"]
        XCTAssertTrue(title.waitForExistence(timeout: 4),
                      "Die aktuelle Coach-Erklärung muss für den Größenvergleich existieren.")
        XCTAssertGreaterThan(title.frame.height, 0,
                             "Die Coach-Erklärung braucht einen messbaren Textframe.")
        return title.frame.height
    }

    @MainActor
    private func dismissGuidedPhaseCurtainIfPresent(in app: XCUIApplication) {
        let continueButton = app.buttons["tutorial.phaseCurtain.continue"]
        if continueButton.waitForExistence(timeout: 2) {
            XCTAssertEqual(continueButton.label, "Bonus-Töpfe ansehen")
            XCTAssertTrue(continueButton.isHittable,
                          "Das erste Lernfenster muss vor der Tischaktion bewusst bestätigt werden können.")
            continueButton.tap()
        }
    }

    @MainActor
    private func rotateForegroundAppToLandscape(_ app: XCUIApplication) {
        app.activate()
        XCTAssertEqual(app.state, .runningForeground, "Nur die laufende Lernbühne darf rotiert werden.")
        XCUIDevice.shared.orientation = .landscapeLeft
        assertWindow(in: app, hasOrientation: .landscape)

        let settledFrame = app.windows.firstMatch.frame
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertEqual(
            app.windows.firstMatch.frame,
            settledFrame,
            "Das App-Fenster muss nach der Rotation einen stabilen Landscape-Frame halten."
        )
        XCTAssertEqual(app.state, .runningForeground, "Die Rotation darf nicht auf SpringBoard enden.")
    }

    @MainActor
    private func assertSmallPhoneLandscapeWindow(in app: XCUIApplication) {
        let frame = app.windows.firstMatch.frame
        XCTAssertGreaterThan(frame.width, frame.height)
        XCTAssertLessThanOrEqual(
            frame.height,
            390,
            "Dieser separate Gate ist absichtlich an die kurze SE-Landscape-Höhe gebunden."
        )
        XCTAssertGreaterThanOrEqual(
            frame.width,
            650,
            "Ein verbliebener 375 x 667-Portraitframe darf nicht als Landscape-Pass gelten."
        )
    }

    @MainActor
    private func assertInitialLandscapeLearningViewport(in app: XCUIApplication) {
        let windowFrame = app.windows.firstMatch.frame
        let stageScroll = app.scrollViews["firstRun.learningScroll"]
        XCTAssertTrue(stageScroll.waitForExistence(timeout: 4), "Der AX-Lernviewport muss existieren.")
        let viewport = windowFrame.intersection(stageScroll.frame)

        XCTAssertFalse(viewport.isNull || viewport.isEmpty, "Der Lernviewport muss das sichtbare App-Fenster schneiden.")
        XCTAssertTrue(
            contains(windowFrame, stageScroll.frame),
            "Der Lernviewport darf nicht selbst vom App-Fenster geclippt werden: \(stageScroll.frame) in \(windowFrame)."
        )
        XCTAssertGreaterThanOrEqual(
            viewport.width,
            windowFrame.width * 0.90,
            "Der initiale AX-Lernviewport muss als lesbarer Gesamtframe fast die volle Landscape-Breite nutzen."
        )
        XCTAssertGreaterThanOrEqual(
            viewport.height,
            160,
            "Der initiale AX-Lernviewport darf nicht unter dem fixen Kopfbereich kollabieren."
        )

        let elements: [(name: String, element: XCUIElement)] = [
            ("Disc", app.descendants(matching: .any)["firstRun.learningBoard"]),
            ("Coach", app.otherElements["firstRun.coach"]),
            ("Hand", app.descendants(matching: .any)["firstRun.learningHand"])
        ] + (1...3).map { seat in
            ("Gegnerplatz \(seat)", app.descendants(matching: .any)["firstRun.opponent.\(seat)"])
        }

        for item in elements {
            XCTAssertTrue(item.element.waitForExistence(timeout: 4), "\(item.name) muss im Lernviewport existieren.")
            let frame = item.element.frame
            XCTAssertGreaterThan(frame.width, 0, "\(item.name) braucht einen messbaren Frame.")
            XCTAssertGreaterThan(frame.height, 0, "\(item.name) braucht einen messbaren Frame.")
            XCTAssertLessThanOrEqual(
                frame.width,
                viewport.width + 1,
                "\(item.name) ist mit \(frame) breiter als der sichtbare Lernviewport \(viewport)."
            )
            XCTAssertLessThanOrEqual(
                frame.height,
                viewport.height + 1,
                "\(item.name) ist mit \(frame) höher als der sichtbare Lernviewport \(viewport) und daher niemals vollständig revealbar."
            )
        }

        let coach = app.otherElements["firstRun.coach"]
        XCTAssertLessThanOrEqual(
            coach.frame.height,
            min(220, windowFrame.height * 0.60),
            "Die AX-XXXL-Coach-Aktion darf nicht zu einer viewportfüllenden Riesenfläche anwachsen: \(coach.frame)."
        )

        for seat in 1...3 {
            let opponent = app.descendants(matching: .any)["firstRun.opponent.\(seat)"]
            XCTAssertTrue(
                contains(viewport, opponent.frame),
                "Der initiale Gesamtframe muss Gegnerplatz \(seat) vollständig zeigen: \(opponent.frame) in \(viewport)."
            )
        }

        let board = app.descendants(matching: .any)["firstRun.learningBoard"]
        let visibleBoard = viewport.intersection(board.frame)
        XCTAssertGreaterThanOrEqual(
            visibleBoard.height,
            min(44, board.frame.height),
            "Der initiale Gesamtframe muss einen klar lesbaren Disc-Anker zeigen: \(board.frame) in \(viewport)."
        )
        XCTAssertEqual(
            visibleBoard.width,
            board.frame.width,
            accuracy: 1,
            "Die Disc darf initial horizontal nicht geclippt sein: \(board.frame) in \(viewport)."
        )
    }

    @MainActor
    private func assertLandscapeLearningContentCanBeFullyRevealed(in app: XCUIApplication) {
        let windowFrame = app.windows.firstMatch.frame
        let stageScroll = app.scrollViews["firstRun.learningScroll"]
        XCTAssertTrue(stageScroll.waitForExistence(timeout: 4))
        let viewport = windowFrame.intersection(stageScroll.frame)
        let identifiers = [
            "firstRun.opponent.1",
            "firstRun.opponent.2",
            "firstRun.opponent.3",
            "firstRun.learningBoard",
            "firstRun.coach",
            "firstRun.meldMatch",
            "firstRun.learningHand"
        ]

        for identifier in identifiers {
            let element = identifier == "firstRun.meldMatch"
                ? meldMatchAction(in: app)
                : app.descendants(matching: .any)[identifier]
            XCTAssertTrue(element.waitForExistence(timeout: 4), "\(identifier) muss im AX-Lernpfad existieren.")
            for _ in 0..<10 where !contains(viewport, element.frame) {
                if element.frame.midY > viewport.midY {
                    stageScroll.swipeUp()
                } else {
                    stageScroll.swipeDown()
                }
            }
            XCTAssertTrue(
                contains(viewport, element.frame),
                "\(identifier) muss ohne Clipping vollständig in \(viewport) revealbar sein, liegt aber bei \(element.frame)."
            )
            if identifier == "firstRun.meldMatch" {
                XCTAssertTrue(element.isHittable, "Die vollständig sichtbare Coach-Aktion muss bedienbar sein.")
            }
        }
    }

    private func contains(_ outer: CGRect, _ inner: CGRect, tolerance: CGFloat = 1) -> Bool {
        outer.insetBy(dx: -tolerance, dy: -tolerance).contains(inner)
    }

    @MainActor
    private func attachLearningViewportEvidence(in app: XCUIApplication, named name: String) {
        let windowFrame = app.windows.firstMatch.frame
        let viewportFrame = app.scrollViews["firstRun.learningScroll"].frame
        let opponent1Frame = app.descendants(matching: .any)["firstRun.opponent.1"].frame
        let opponent2Frame = app.descendants(matching: .any)["firstRun.opponent.2"].frame
        let opponent3Frame = app.descendants(matching: .any)["firstRun.opponent.3"].frame
        let boardFrame = app.descendants(matching: .any)["firstRun.learningBoard"].frame
        let coachFrame = app.otherElements["firstRun.coach"].frame
        let handFrame = app.descendants(matching: .any)["firstRun.learningHand"].frame
        let lines: [String] = [
            "Window: \(windowFrame)",
            "Learning viewport: \(viewportFrame)",
            "Opponent 1: \(opponent1Frame)",
            "Opponent 2: \(opponent2Frame)",
            "Opponent 3: \(opponent3Frame)",
            "Board: \(boardFrame)",
            "Coach action: \(coachFrame)",
            "Hand: \(handFrame)"
        ]
        attachTextEvidence(lines.joined(separator: "\n"), named: name)
    }

    @MainActor
    private func restoreLearningStageToTop(in app: XCUIApplication) {
        let stageScroll = app.scrollViews["firstRun.learningScroll"]
        guard stageScroll.exists else { return }
        for _ in 0..<3 {
            stageScroll.swipeDown()
        }
    }

    @MainActor
    private func assertMeldMatchIsReachable(in app: XCUIApplication) {
        let action = meldMatchAction(in: app)
        let stageScroll = app.scrollViews["firstRun.learningScroll"]
        XCTAssertTrue(stageScroll.waitForExistence(timeout: 4))
        for _ in 0..<8 where !action.exists || !action.isHittable {
            stageScroll.swipeUp()
        }
        XCTAssertTrue(action.exists && action.isHittable,
                      "Die markierte Trumpfkarte muss als echte Tutorialhandlung erreichbar sein. "
                        + "exists=\(action.exists), hittable=\(action.isHittable), frame=\(action.frame), "
                        + "scroll=\(stageScroll.frame)")
    }

    @MainActor
    private func meldMatchAction(in app: XCUIApplication) -> XCUIElement {
        let identifiedAction = app.buttons["firstRun.meldMatch"]
        if identifiedAction.exists { return identifiedAction }
        return app.buttons["Trumpf-König melden"]
    }

    @MainActor
    private func assertReachableByScrolling(_ identifier: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 4), "\(identifier) muss im Accessibility-Baum existieren.")

        let windowFrame = app.windows.firstMatch.frame
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<8 where !windowFrame.contains(element.frame) || !element.isHittable {
            XCTAssertTrue(scrollView.exists, "\(identifier) braucht auf kleinen Geräten einen echten Scrollpfad.")
            if element.frame.midY > windowFrame.midY {
                scrollView.swipeUp()
            } else {
                scrollView.swipeDown()
            }
        }

        XCTAssertTrue(
            windowFrame.contains(element.frame) && element.isHittable,
            "\(identifier) muss nach dem Scrollen vollständig sichtbar und bedienbar sein: \(element.frame)."
        )
    }

    @MainActor
    private func assertFullFirstRunActionLabels(in app: XCUIApplication) {
        let expectedLabels = [
            "firstRun.intro.primary": "Mitspielen",
            "firstRun.intro.secondary": "Ohne Hinweise starten"
        ]
        for (identifier, expectedLabel) in expectedLabels {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 4), "\(identifier) muss als Button im Accessibility-Baum existieren.")
            XCTAssertEqual(
                button.label,
                expectedLabel,
                "Kompakte Sichtcopy darf das vollständige VoiceOver-Label von \(identifier) nicht kürzen."
            )
        }
    }

    @MainActor
    private func assertVisibleIntroSurfacesDoNotOverlap(in app: XCUIApplication, context: String) {
        let windowFrame = app.windows.firstMatch.frame
        let identifiers = [
            "firstRun.intro.title",
            "firstRun.intro.body",
            "firstRun.intro.primary",
            "firstRun.intro.secondary"
        ]
        let surfaces: [(identifier: String, frame: CGRect)] = identifiers.compactMap { identifier in
            let element = app.descendants(matching: .any)[identifier]
            guard element.exists || element.waitForExistence(timeout: 3) else {
                XCTFail("\(identifier) fehlt bei \(context).")
                return nil
            }
            let visibleFrame = element.frame.intersection(windowFrame)
            guard !visibleFrame.isNull, visibleFrame.width >= 2, visibleFrame.height >= 2 else {
                return nil
            }
            return (identifier, visibleFrame)
        }

        for firstIndex in surfaces.indices {
            for secondIndex in surfaces.indices where secondIndex > firstIndex {
                let first = surfaces[firstIndex]
                let second = surfaces[secondIndex]
                let overlap = first.frame.intersection(second.frame)
                XCTAssertFalse(
                    !overlap.isNull && overlap.width > 1 && overlap.height > 1,
                    "\(context): \(first.identifier) \(first.frame) überlagert \(second.identifier) \(second.frame) auf \(overlap)."
                )
            }
        }
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        app.activate()
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertEqual(app.state, .runningForeground, "\(name) darf keinen verdeckten SpringBoard-Zustand aufnehmen.")
        XCTAssertTrue(app.windows.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attachIntroFrameEvidence(in app: XCUIApplication, named name: String) {
        var lines = ["Fenster: \(app.windows.firstMatch.frame)"]
        if app.scrollViews.firstMatch.exists {
            lines.append("Scroll: \(app.scrollViews.firstMatch.frame)")
        }
        for identifier in [
            "firstRun.intro.title",
            "firstRun.intro.body",
            "firstRun.intro.primary",
            "firstRun.intro.secondary"
        ] {
            lines.append("\(identifier): \(app.descendants(matching: .any)[identifier].frame)")
        }
        attachTextEvidence(lines.joined(separator: "\n"), named: name)
    }

    private func attachTextEvidence(_ text: String, named name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func localizedArguments(_ arguments: [String]) -> [String] {
        arguments + ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    }

    private func standardContentSizeArguments(_ arguments: [String]) -> [String] {
        localizedArguments(arguments) + [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryL"
        ]
    }

    private func accessibilityXXXLArguments(_ arguments: [String]) -> [String] {
        localizedArguments(arguments) + [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
    }
}

private enum ExpectedOrientation {
    case portrait
    case landscape
}
