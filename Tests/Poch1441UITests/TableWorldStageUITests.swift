import XCTest

final class TableWorldStageUITests: XCTestCase {
    @MainActor
    func testPhase1PortraitMaterialPresentation() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-dealDone",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase1.board", in: app)
        attachScreenshot(of: app, named: "poch-disc-phase1-portrait-material")
    }

    @MainActor
    func testPhase1EmptyCenterMaterialPresentation() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-dealDone",
            "-emptyCenterMaterialQA",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase1.board", in: app)
        attachScreenshot(of: app, named: "poch-disc-phase1-empty-center-material")
    }

    @MainActor
    func testPhase2PortraitMaterialAndFreeStageCenter() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-pochenStart",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase2.board", in: app)
        attachScreenshot(of: app, named: "poch-disc-phase2-portrait-material-centered")
    }

    @MainActor
    func testPhase1LandscapeMaterialAndSeatAxis() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-dealDone",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.landscapeLeft, in: app)
        assertBoard("table.world.phase1.board", in: app)
        assertPhase1LandscapeZones(in: app)
        attachScreenshot(of: app, named: "poch-disc-phase1-landscape-material")
    }

    @MainActor
    func testPochDiscCompositionInPortraitAndLandscape() {
        let app = XCUIApplication()
        for phase in ["phase1", "phase2"] {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                app.launchArguments = localizedArguments([
                    phase == "phase2" ? "-pochenStart" : "-dealDone",
                    "-coachOff",
                    "-players=4"
                ])
                XCUIDevice.shared.orientation = orientation
                app.launch()
                assertWindowOrientation(orientation, in: app)

                let identifier = "table.world.\(phase).board"
                assertBoard(identifier, in: app)
                if phase == "phase1", orientation == .landscapeLeft {
                    assertPhase1LandscapeZones(in: app)
                }
                let suffix = orientation == .portrait ? "portrait" : "landscape"
                attachScreenshot(of: app, named: "poch-disc-\(phase)-\(suffix)")
                app.terminate()
            }
        }
    }

    @MainActor
    func testSaturatedPileRevealsItsPublicValue() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-pochenStart",
            "-boardOverflowQA",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase2.board", in: app)
        let sequence = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "FOLGE, 13")).firstMatch
        XCTAssertTrue(sequence.waitForExistence(timeout: 3),
                      "Die Sequenzmulde muss ihren öffentlichen Wert benennen.")
        XCTAssertTrue(sequence.label.hasSuffix(", 13"),
                      "Der QA-Seed muss die erste physisch gesättigte R1-Stufe zeigen.")
        attachScreenshot(of: app, named: "poch-disc-saturated-pile-value")
    }

    @MainActor
    func testGuidedTableFundingUsesVisibleR1WavesAndSettles() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-tutorialSeed",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        dismissTutorialCurtainIfNeeded(in: app)
        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4),
                      "Der echte Tutorialflow muss mit dem ersten R1-Stein beginnen.")
        openingToken.tap()

        Thread.sleep(forTimeInterval: 0.42)
        XCTAssertTrue(app.otherElements["firstRun.coach"].exists,
                      "Die automatische Tischmontage muss ihren aktuellen Beat erklären.")
        XCTAssertFalse(app.buttons["firstRun.coachAction"].exists,
                       "Die Tischmontage darf keinen passiven Weiter-Tap verlangen.")
        attachScreenshot(of: app, named: "guided-r1-funding-wave")

        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 15),
                      "Nach der Montage muss Trumpf wieder eine echte Tutorialaktion sein.")
        XCTAssertEqual(action.label, "Trumpf aufdecken")
        attachScreenshot(of: app, named: "guided-r1-funding-settled")
    }

    @MainActor
    func testGuidedTableFundingSettlesImmediatelyWithReducedMotion() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-tutorialSeed",
            "-reduceMotionQA",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        dismissTutorialCurtainIfNeeded(in: app)
        let openingToken = app.buttons["firstRun.openingToken"]
        XCTAssertTrue(openingToken.waitForExistence(timeout: 4))
        let startedAt = Date()
        openingToken.tap()

        let learningState = app.descendants(matching: .any)
            .matching(identifier: "firstRun.learningState").firstMatch
        XCTAssertTrue(learningState.waitForExistence(timeout: 2))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Dein Zug"),
            object: learningState
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 2), .completed)
        // Zwei feste XCUI-Pollintervalle liegen bereits bei rund zwei Sekunden;
        // der normale Vier-Wellen-Pfad benötigt dagegen deutlich über vier.
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 3.0,
                          "Reduced Motion darf keine unsichtbare R1-Welle abwarten.")
        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 2))
        XCTAssertEqual(action.label, "Trumpf aufdecken")
        attachScreenshot(of: app, named: "guided-r1-funding-reduced-motion")
    }

    @MainActor
    func testMeldPayoutUsesVisibleHeavyR1AndSettlesAtContact() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-meldPayoutQA",
            "-portraitQA",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase1.board", in: app)
        dismissTutorialCurtainIfNeeded(in: app)
        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()
        let flight = app.descendants(matching: .any)
            .matching(identifier: "phase1.meld.flight").firstMatch
        let target = app.descendants(matching: .any)
            .matching(identifier: "phase1.meld.target").firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 3),
                      "Der Materialtransfer braucht während des Flugs ein eindeutiges Gewinnerziel.")
        XCTAssertTrue(flight.waitForExistence(timeout: 3),
                      "Die Meldung muss als sichtbarer R1-Transfer beginnen.")
        attachImmediateScreenshot(named: "meld-payout-heavy-r1-flight")

        let presentation = app.descendants(matching: .any)
            .matching(identifier: "phase1.presentation").firstMatch
        XCTAssertTrue(presentation.waitForExistence(timeout: 1))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "5/5"),
            object: presentation
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed,
                       "Alle fünf Gewinnerstacks dürfen erst am Materialkontakt aufholen.")
        XCTAssertFalse(flight.exists,
                       "Nach der vollständigen Abrechnung darf kein R1-Flug übrig bleiben.")
        attachScreenshot(of: app, named: "meld-payout-heavy-r1-settled")
    }

    @MainActor
    func testMeldPayoutSettlesWhenReduceMotionChangesLive() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-meldPayoutQA",
            "-meldPayoutLiveReduceMotionQA",
            "-portraitQA",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        dismissTutorialCurtainIfNeeded(in: app)
        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()
        let presentation = app.descendants(matching: .any)
            .matching(identifier: "phase1.presentation").firstMatch
        XCTAssertTrue(presentation.waitForExistence(timeout: 1))
        let startedAt = Date()
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "5/5"),
            object: presentation
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 1.5), .completed,
                       "Live Reduced Motion muss alle offenen Kontakte ohne Restzeit setzen.")
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1.2)
        XCTAssertEqual(presentation.value as? String, "5/5")
        attachScreenshot(of: app, named: "meld-payout-live-reduced-motion")
    }

    @MainActor
    func testMeldPayoutFastTransitionRejectsStaleContactInCompactLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-meldPayoutQA",
            "-meldPayoutFastTransitionQA",
            "-landscapeQA",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.landscapeLeft, in: app)
        dismissTutorialCurtainIfNeeded(in: app)
        let action = app.buttons["firstRun.coachAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()

        let phase2Board = app.images.matching(identifier: "table.world.phase2.board").firstMatch
        XCTAssertTrue(phase2Board.waitForExistence(timeout: 3),
                      "Der schnelle Übergang nach Pochen muss stabil abschließen.")
        let flight = app.descendants(matching: .any)
            .matching(identifier: "phase1.meld.flight").firstMatch
        XCTAssertFalse(flight.exists,
                       "Ein alter Phase-1-Flug darf nicht in Phase 2 weiterleben.")
        assertBoard("table.world.phase2.board", in: app)
        attachScreenshot(of: app, named: "meld-payout-fast-transition-landscape")
    }

    @MainActor
    func testPochPayoutLandsBeforeFastPhaseTransition() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-pochenStart",
            "-pochPayoutQA",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase2.board", in: app)
        Thread.sleep(forTimeInterval: 2.22)
        attachImmediateScreenshot(named: "poch-payout-heavy-r1-flight")

        let continueButton = app.buttons["phase2.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2),
                      "Die echte Bietrunde muss das Phase-2-Ergebnis zeigen.")

        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: continueButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 2), .completed)
        assertPhase2ResultZones(in: app)
        attachScreenshot(of: app, named: "poch-payout-settled")

        continueButton.tap()
        let phase3 = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase3.waitForExistence(timeout: 3),
                      "Direkt nach dem Kontakt muss der Übergang nach Phase 3 stabil bleiben.")
    }

    @MainActor
    func testPochPayoutReducedMotionDoesNotWaitForInvisibleFlight() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-pochenStart",
            "-pochPayoutQA",
            "-reduceMotionQA",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.portrait, in: app)
        assertBoard("table.world.phase2.board", in: app)
        Thread.sleep(forTimeInterval: 2.22)

        let continueButton = app.buttons["phase2.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        XCTAssertTrue(continueButton.isEnabled,
                      "Reduced Motion darf keine unsichtbare Auszahlung abwarten.")
        attachScreenshot(of: app, named: "poch-payout-reduced-motion")

        continueButton.tap()
        let phase3 = app.descendants(matching: .any)["table.world.phase3"]
        XCTAssertTrue(phase3.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPochPayoutResultFitsCompactLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-pochenStart",
            "-pochPayoutQA",
            "-landscapeQA",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertWindowOrientation(.landscapeLeft, in: app)
        assertBoard("table.world.phase2.board", in: app)
        let continueButton = app.buttons["phase2.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 6))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: continueButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 2), .completed)
        assertPhase2ResultZones(in: app)
        attachScreenshot(of: app, named: "poch-payout-landscape-settled")
    }

    @MainActor
    private func assertPhase2ResultZones(in app: XCUIApplication) {
        // SwiftUI führt das innere Banner bewusst in den stabilen äußeren
        // Aktionscontainer zusammen. Das ist derselbe öffentliche Vertrag,
        // den der Dynamic-Type-Gate über beide Ergebnisvarianten prüft.
        let result = app.otherElements.matching(identifier: "phase2.actions").firstMatch
        let hand = app.otherElements.matching(identifier: "phase2.hand").firstMatch
        let continueButton = app.buttons["phase2.continue"]
        let opponents = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase2.opponent.")
        )

        XCTAssertTrue(result.waitForExistence(timeout: 2))
        XCTAssertTrue(hand.waitForExistence(timeout: 2))
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["phase2.newRound"].exists,
                       "Phase 2 darf keine regelwidrige neue Runde anbieten.")
        XCTAssertGreaterThan(opponents.count, 0)

        let resultBottom = continueButton.frame.maxY
        for index in 0..<opponents.count {
            XCTAssertLessThanOrEqual(resultBottom, opponents.element(boundBy: index).frame.minY,
                                     "Ergebnis und Gegner benötigen getrennte Bühnenzonen.")
        }
        XCTAssertFalse(result.frame.intersects(hand.frame),
                       "Ergebnis und eigene Hand dürfen sich nicht überlagern.")
    }

    @MainActor
    private func assertPhase1LandscapeZones(in app: XCUIApplication) {
        let board = app.images.matching(identifier: "table.world.phase1.board").firstMatch
        let opponents = app.descendants(matching: .any)
            .matching(identifier: "table.world.phase1.opponents").firstMatch
        let hand = app.descendants(matching: .any)
            .matching(identifier: "table.world.phase1.hand").firstMatch

        XCTAssertTrue(opponents.waitForExistence(timeout: 3),
                      "Melden braucht in Landscape eine stabile linke Gegnerachse.")
        XCTAssertTrue(hand.waitForExistence(timeout: 3),
                      "Die eigene Hand muss in Landscape eine eigene untere Zone behalten.")
        XCTAssertFalse(opponents.frame.intersects(board.frame),
                       "Gegnerachse und Disc dürfen sich nicht überlagern.")
        XCTAssertFalse(hand.frame.intersects(board.frame),
                       "Hand und Disc dürfen sich nicht überlagern.")
        XCTAssertLessThan(opponents.frame.midX, hand.frame.midX,
                          "Die Gegnerachse muss links von der Handherkunft stabil bleiben.")
    }

    @MainActor
    private func assertWindowOrientation(_ orientation: UIDeviceOrientation,
                                         in app: XCUIApplication) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        let predicate = NSPredicate { _, _ in
            orientation == .portrait
                ? window.frame.height > window.frame.width
                : window.frame.width > window.frame.height
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed,
                       "Das App-Fenster muss die geforderte Orientierung angenommen haben: \(window.frame).")
    }

    @MainActor
    func testTravelWorldUsesTheSharedBoardAcrossMeldAndPochStages() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-tableWorld=unterwegs",
            "-dealDone",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertBoard("table.world.phase1.board", in: app)
        attachScreenshot(of: app, named: "unterwegs-phase1-shared-board")
        app.terminate()

        app.launchArguments = localizedArguments([
            "-tableWorld=unterwegs",
            "-pochenStart",
            "-coachOff",
            "-players=4"
        ])
        app.launch()

        assertBoard("table.world.phase2.board", in: app)
        attachScreenshot(of: app, named: "unterwegs-phase2-shared-board")
        app.terminate()
    }

    @MainActor
    private func assertBoard(_ identifier: String, in app: XCUIApplication) {
        // SwiftUI propagates a container identifier to its accessible children.
        // The board base is the only image in that subtree and is therefore the
        // stable material-stage probe rather than an ambiguous `.any` query.
        let board = app.images.matching(identifier: identifier).firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5), "\(identifier) muss sichtbar sein.")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        XCTAssertTrue(window.frame.intersects(board.frame), "\(identifier) liegt außerhalb des Fensters.")
        XCTAssertGreaterThanOrEqual(board.frame.width, 120, "Das Board muss materiell lesbar bleiben.")
        XCTAssertGreaterThanOrEqual(board.frame.height, 120, "Das Board muss materiell lesbar bleiben.")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        app.activate()
        Thread.sleep(forTimeInterval: 0.3)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attachImmediateScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func localizedArguments(_ arguments: [String]) -> [String] {
        arguments + [
            "-sound", "false",
            "-haptics", "false",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE"
        ]
    }

    @MainActor
    private func dismissTutorialCurtainIfNeeded(in app: XCUIApplication) {
        let curtain = app.buttons["tutorial.phaseCurtain.continue"]
        if curtain.waitForExistence(timeout: 3), curtain.isHittable {
            curtain.tap()
        }
    }
}
