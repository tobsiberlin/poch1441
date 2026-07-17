import XCTest

final class FirstRunUITests: XCTestCase {
    @MainActor
    func testFirstRunKeepsItsMeaningAcrossRotation() {
        let app = XCUIApplication()
        app.launchArguments = localizedArguments(["-firstRun", "-players=4"])

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
    func testFirstRunReflowsAtAccessibilityXXXLOnSmallPhone() {
        let standardApp = XCUIApplication()
        standardApp.terminate()
        XCUIDevice.shared.orientation = .portrait
        standardApp.launchArguments = standardContentSizeArguments(["-firstRun", "-players=4"])
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
        accessibilityApp.launchArguments = accessibilityXXXLArguments(["-firstRun", "-players=4"])
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
        app.launchArguments = accessibilityXXXLArguments(["-firstRun", "-players=4"])
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

        assertWindow(in: app, hasOrientation: .portrait)
        assertLearningState("Verbinden", in: app)
        assertCoachActionIsReachable(in: app)
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
        assertWindow(in: standardApp, hasOrientation: .portrait)
        assertLearningState("Verbinden", in: standardApp)
        let standardActionHeight = coachActionHeight(in: standardApp)
        standardApp.terminate()

        let landscapeApp = XCUIApplication()
        landscapeApp.terminate()
        XCUIDevice.shared.orientation = .portrait
        landscapeApp.launchArguments = accessibilityXXXLArguments(arguments)
        landscapeApp.launch()
        assertWindow(in: landscapeApp, hasOrientation: .portrait)
        assertLearningState("Verbinden", in: landscapeApp)
        let accessibilityActionHeight = coachActionHeight(in: landscapeApp)
        XCTAssertGreaterThan(
            accessibilityActionHeight,
            standardActionHeight * 1.20,
            "Der Gate muss eine tatsächlich größere AX-XXXL-Aktion prüfen und darf nicht nur denselben Standardframe drehen."
        )
        attachTextEvidence(
            "Coach-Aktion Standard: \(standardActionHeight) pt\nCoach-Aktion AX XXXL: \(accessibilityActionHeight) pt",
            named: "first-run-learning-ax-xxxl-size-proof"
        )

        rotateForegroundAppToLandscape(landscapeApp)
        assertSmallPhoneLandscapeWindow(in: landscapeApp)
        assertLearningState("Verbinden", in: landscapeApp)
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
        app.launchArguments = localizedArguments(["-firstRun", "-players=4"])
        app.launch()

        let enterTable = app.buttons["firstRun.intro.primary"]
        XCTAssertTrue(enterTable.waitForExistence(timeout: 4))
        enterTable.tap()
        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4))
        openingToken.tap()
        XCUIDevice.shared.orientation = .landscapeLeft

        assertWindow(in: app, hasOrientation: .landscape)
        XCTAssertTrue(
            app.buttons["firstRun.coachAction"].waitForExistence(timeout: 4),
            "Rotation während des Kontakts muss genau einmal in den nächsten Beat führen."
        )
        assertLearningState("Orientieren", in: app)
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

        let windowFrame = app.windows.firstMatch.frame
        let identifiers = [
            "firstRun.intro.title",
            "firstRun.intro.body",
            "firstRun.intro.goal",
            "firstRun.intro.primary",
            "firstRun.intro.secondary"
        ]
        let scrollView = app.scrollViews.firstMatch

        for identifier in identifiers {
            let element = app.descendants(matching: .any)[identifier]
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
                isFullyVisible && frame.width >= 44 && frame.height >= 20,
                "\(identifier) liegt mit Frame \(frame) außerhalb von \(windowFrame)."
            )
        }

        let board = app.descendants(matching: .any)["firstRun.intro.board"]
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
        let protectedFrames = [
            app.descendants(matching: .any)["firstRun.intro.goal"].frame,
            app.descendants(matching: .any)["firstRun.intro.primary"].frame,
            app.descendants(matching: .any)["firstRun.intro.secondary"].frame
        ]
        for protectedFrame in protectedFrames {
            XCTAssertFalse(
                board.frame.intersects(protectedFrame),
                "Disc und Informations- oder Aktionsfläche dürfen sich nicht überschneiden."
            )
        }
        for seat in 1...3 {
            let opponent = app.descendants(matching: .any)["firstRun.opponent.\(seat)"]
            XCTAssertTrue(
                windowFrame.contains(opponent.frame),
                "Tutorialplatz \(seat) muss vollständig im App-Fenster liegen."
            )
            XCTAssertFalse(
                board.frame.intersects(opponent.frame),
                "Disc und Tutorialplatz \(seat) dürfen sich in \(orientation) nicht überschneiden."
            )
        }
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
    private func assertLearningStageDoesNotOverlap(in app: XCUIApplication, context: String) {
        let board = app.descendants(matching: .any)["firstRun.learningBoard"]
        let coach = app.buttons["firstRun.coachAction"]
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
    private func coachActionHeight(in app: XCUIApplication) -> CGFloat {
        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 4), "Die Coach-Aktion muss für den Größenvergleich existieren.")
        XCTAssertEqual(
            action.label,
            "Karte und Mulde verbinden",
            "Der AX-Gate darf die vollständige deutsche Aktionssemantik nicht verkürzen."
        )
        XCTAssertGreaterThan(action.frame.height, 0, "Die Coach-Aktion braucht einen messbaren Frame.")
        return action.frame.height
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
            ("Coach", app.buttons["firstRun.coachAction"]),
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

        let coach = app.buttons["firstRun.coachAction"]
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
            "firstRun.coachAction",
            "firstRun.learningHand"
        ]

        for identifier in identifiers {
            let element = app.descendants(matching: .any)[identifier]
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
            if identifier == "firstRun.coachAction" {
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
        let coachFrame = app.buttons["firstRun.coachAction"].frame
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
    private func assertCoachActionIsReachable(in app: XCUIApplication) {
        let action = app.buttons["firstRun.coachAction"]
        let stageScroll = app.scrollViews["firstRun.learningScroll"]
        XCTAssertTrue(stageScroll.waitForExistence(timeout: 4))
        for _ in 0..<8 where !action.exists || !action.isHittable {
            stageScroll.swipeUp()
        }
        XCTAssertTrue(action.exists && action.isHittable,
                      "Die Primäraktion muss innerhalb der begrenzten Coach-Zone scrollbar erreichbar sein.")
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
            "firstRun.intro.primary": "Am Tisch Platz nehmen",
            "firstRun.intro.secondary": "Ohne Einführung spielen"
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
            "firstRun.intro.board",
            "firstRun.opponent.1",
            "firstRun.opponent.2",
            "firstRun.opponent.3",
            "firstRun.intro.goal",
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
            "firstRun.intro.board",
            "firstRun.opponent.1",
            "firstRun.opponent.2",
            "firstRun.opponent.3",
            "firstRun.intro.goal",
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
