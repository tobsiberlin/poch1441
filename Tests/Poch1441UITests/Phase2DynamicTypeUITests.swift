import XCTest

final class Phase2DynamicTypeUITests: XCTestCase {
    private enum ContentSizeProfile: String {
        case standard = "UICTContentSizeCategoryL"
        case accessibilityXXXL = "UICTContentSizeCategoryAccessibilityXXXL"
    }

    private struct ResultSnapshot {
        let window: CGRect
        let board: CGRect
        let result: CGRect
        let newRound: CGRect
        let continueButton: CGRect
        let hand: CGRect
        let opponents: [CGRect]
    }

    @MainActor
    func testPhase2ResultActuallyReflowsAtAccessibilityXXXLOnCompactPortrait() throws {
        XCUIDevice.shared.orientation = .portrait

        let standardApp = launchResolvedPhase2(profile: .standard)
        let standard = try resultSnapshot(in: standardApp, context: "Standardtext")
        try requireCompactPhone(standard.window)
        attachEvidence(of: standardApp,
                       snapshot: standard,
                       named: "phase2-dynamic-type-standard-compact-portrait")
        standardApp.terminate()

        let accessibilityApp = launchResolvedPhase2(profile: .accessibilityXXXL)
        let accessibility = try resultSnapshot(in: accessibilityApp,
                                                context: "Accessibility XXXL")
        try requireCompactPhone(accessibility.window)
        assertResultContract(accessibility,
                             in: accessibilityApp,
                             context: "Accessibility XXXL, kompaktes Portrait")
        attachEvidence(of: accessibilityApp,
                       snapshot: accessibility,
                       named: "phase2-dynamic-type-axxxl-compact-portrait")

        XCTAssertGreaterThan(
            accessibility.result.height,
            standard.result.height + 1,
            "Accessibility XXXL muss die Phase-2-Ergebnisaktion sichtbar reflowen; " +
            "ein identischer fester 64-pt-Container ist kein Dynamic-Type-Beleg."
        )
        XCTAssertTrue(
            accessibility.newRound.height > standard.newRound.height + 1 ||
                accessibility.continueButton.height > standard.continueButton.height + 1,
            "Mindestens eine Aktion muss für Accessibility XXXL mehr vertikalen Raum erhalten."
        )
    }

    @MainActor
    func testPhase2AccessibilityXXXLResultFitsCompactLandscapeAndContinues() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchResolvedPhase2(profile: .accessibilityXXXL,
                                       additionalArguments: ["-landscapeQA"])
        let snapshot = try resultSnapshot(in: app,
                                          context: "Accessibility XXXL, kompaktes Landscape")
        try requireCompactLandscape(snapshot.window)
        assertResultContract(snapshot,
                             in: app,
                             context: "Accessibility XXXL, kompaktes Landscape")
        attachEvidence(of: app,
                       snapshot: snapshot,
                       named: "phase2-dynamic-type-axxxl-compact-landscape")

        continueToPhase3(in: app)
    }

    @MainActor
    func testPhase2AccessibilityXXXLResultFitsRepresentativePortraitAndContinues() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchResolvedPhase2(profile: .accessibilityXXXL)
        let snapshot = try resultSnapshot(in: app,
                                          context: "Accessibility XXXL, Zielbreite")
        guard snapshot.window.width >= 390 else {
            throw XCTSkip("Dieser Gate wird zusätzlich auf einer repräsentativen Portrait-Zielbreite ab 390 pt ausgeführt.")
        }

        assertResultContract(snapshot,
                             in: app,
                             context: "Accessibility XXXL, Zielbreite \(snapshot.window.width) pt")
        attachEvidence(of: app,
                       snapshot: snapshot,
                       named: "phase2-dynamic-type-axxxl-representative-portrait")

        continueToPhase3(in: app)
    }

    @MainActor
    private func launchResolvedPhase2(profile: ContentSizeProfile,
                                      additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-pochenStart",
            "-pochPayoutQA",
            "-reduceMotionQA",
            "-coachOff",
            "-players=4"
        ] + additionalArguments + [
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", profile.rawValue,
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
        app.launch()
        return app
    }

    @MainActor
    private func resultSnapshot(in app: XCUIApplication,
                                context: String) throws -> ResultSnapshot {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4), "\(context): Hauptfenster fehlt.")

        let board = app.images.matching(identifier: "table.world.phase2.board").firstMatch
        let result = app.otherElements.matching(identifier: "phase2.result").firstMatch
        let newRound = app.buttons["phase2.newRound"]
        let continueButton = app.buttons["phase2.continue"]
        let hand = app.otherElements.matching(identifier: "phase2.hand").firstMatch
        let opponentQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase2.opponent.")
        )

        XCTAssertTrue(board.waitForExistence(timeout: 6), "\(context): Poch-Scheibe fehlt.")
        XCTAssertTrue(result.waitForExistence(timeout: 6), "\(context): Ergebnisbereich fehlt.")
        XCTAssertTrue(newRound.waitForExistence(timeout: 2), "\(context): Neue Runde fehlt.")
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2), "\(context): Weiter fehlt.")
        XCTAssertTrue(hand.waitForExistence(timeout: 2), "\(context): Handbereich fehlt.")
        XCTAssertGreaterThan(opponentQuery.count, 0, "\(context): Gegnerbereiche fehlen.")

        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: continueButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed,
                       "\(context): Weiter muss nach der atomaren Auszahlung bedienbar sein.")

        return ResultSnapshot(
            window: window.frame,
            board: board.frame,
            result: result.frame,
            newRound: newRound.frame,
            continueButton: continueButton.frame,
            hand: hand.frame,
            opponents: (0..<opponentQuery.count).map { opponentQuery.element(boundBy: $0).frame }
        )
    }

    @MainActor
    private func assertResultContract(_ snapshot: ResultSnapshot,
                                      in app: XCUIApplication,
                                      context: String) {
        let visibleWindow = snapshot.window.insetBy(dx: -0.5, dy: -0.5)
        for (name, frame) in [
            ("Ergebnis", snapshot.result),
            ("Neue Runde", snapshot.newRound),
            ("Weiter", snapshot.continueButton)
        ] {
            XCTAssertTrue(visibleWindow.contains(frame),
                          "\(context): \(name) liegt mit \(frame) nicht vollständig in \(snapshot.window).")
        }

        XCTAssertGreaterThan(visibleAreaRatio(of: snapshot.board, in: snapshot.window), 0.8,
                             "\(context): Die Poch-Scheibe muss substanziell sichtbar bleiben.")
        XCTAssertGreaterThan(visibleAreaRatio(of: snapshot.hand, in: snapshot.window), 0.2,
                             "\(context): Der bewusst einlaufende Kartenfächer muss lesbar bleiben.")

        XCTAssertFalse(snapshot.result.intersects(snapshot.hand),
                       "\(context): Ergebnis und Hand dürfen sich nicht überlagern.")
        XCTAssertGreaterThanOrEqual(snapshot.newRound.height, 44,
                                    "\(context): Neue Runde braucht mindestens 44 pt Touchhöhe.")
        XCTAssertGreaterThanOrEqual(snapshot.continueButton.height, 44,
                                    "\(context): Weiter braucht mindestens 44 pt Touchhöhe.")

        for opponent in snapshot.opponents {
            XCTAssertFalse(snapshot.result.intersects(opponent),
                           "\(context): Ergebnis und Gegner benötigen getrennte Zonen.")
            XCTAssertFalse(snapshot.hand.intersects(opponent),
                           "\(context): Hand und Gegner benötigen getrennte Zonen.")
        }

        let newRound = app.buttons["phase2.newRound"]
        let continueButton = app.buttons["phase2.continue"]
        XCTAssertEqual(newRound.label, "Neue Runde",
                       "\(context): Das VoiceOver-Label darf nicht gekürzt werden.")
        XCTAssertEqual(continueButton.label, "Weiter · Ausspielen",
                       "\(context): Das VoiceOver-Label darf nicht gekürzt werden.")
        XCTAssertTrue(newRound.isHittable, "\(context): Neue Runde muss erreichbar sein.")
        XCTAssertTrue(continueButton.isHittable, "\(context): Weiter muss erreichbar sein.")
    }

    @MainActor
    private func continueToPhase3(in app: XCUIApplication) {
        let continueButton = app.buttons["phase2.continue"]
        continueButton.tap()
        let phase3 = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase3.waitForExistence(timeout: 4),
                      "Die echte Phase-2-Aktion muss auch bei Accessibility XXXL nach Phase 3 führen.")
    }

    private func requireCompactPhone(_ window: CGRect) throws {
        guard window.width <= 390 else {
            throw XCTSkip("Dieser Gate wird auf einer kompakten iPhone-Klasse bis 390 pt ausgeführt.")
        }
    }

    private func requireCompactLandscape(_ window: CGRect) throws {
        guard window.width <= 667, window.height <= 375 else {
            throw XCTSkip("Dieser Gate wird im kompakten 667-x-375-Landscape ausgeführt.")
        }
    }

    private func visibleAreaRatio(of frame: CGRect, in viewport: CGRect) -> CGFloat {
        guard frame.width > 0, frame.height > 0 else { return 0 }
        let visible = frame.intersection(viewport)
        guard !visible.isNull else { return 0 }
        return (visible.width * visible.height) / (frame.width * frame.height)
    }

    @MainActor
    private func attachEvidence(of app: XCUIApplication,
                                snapshot: ResultSnapshot,
                                named name: String) {
        app.activate()
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let metrics = XCTAttachment(string: """
        viewport: \(snapshot.window)
        board: \(snapshot.board)
        result: \(snapshot.result)
        newRound: \(snapshot.newRound)
        continue: \(snapshot.continueButton)
        hand: \(snapshot.hand)
        opponents: \(snapshot.opponents)
        """)
        metrics.name = "\(name)-frames"
        metrics.lifetime = .keepAlways
        add(metrics)
    }
}
