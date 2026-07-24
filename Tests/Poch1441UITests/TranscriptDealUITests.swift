import XCTest

final class TranscriptDealUITests: XCTestCase {
    @MainActor
    func testStandardTranscriptReachesEightContactsWithAtMostTwoMovingCards() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments(["-transcriptDealQA", "-coachOff", "-players=4"])

        app.launch()
        let status = dealStatus(in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 3),
                      "Der Transcript-Dealstatus muss vor der Zeitmessung sichtbar sein.")
        let startedAt = Date()
        waitForDealCount(8, status: status, in: app, timeout: 7)
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertTrue(status.exists, "Der Standardpfad muss acht echte Kontaktmarker erreichen.")
        XCTAssertLessThan(elapsed, 5, "Acht sichtbare Kontakte dürfen keine versteckte Langzeitpause enthalten.")
        assertAtMostTwoMovingCards(in: app, samples: 24)
        attachScreenshot(of: app, named: "transcript-deal-stage3-standard-eight-contact")
    }

    @MainActor
    func testReducedMotionTranscriptReachesEightContactsWithoutSpatialFlight() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments([
            "-transcriptDealReducedMotionQA", "-coachOff", "-players=4"
        ])

        app.launch()
        let status = dealStatus(in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 3),
                      "Der Reduced-Motion-Status muss vor der Zeitmessung sichtbar sein.")
        let startedAt = Date()
        waitForDealCount(8, status: status, in: app, timeout: 5)
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertTrue(status.exists, "Reduced Motion muss dieselben acht Kontaktmarker erreichen.")
        XCTAssertLessThan(elapsed, 3, "Reduced Motion darf ab sichtbarem Start keine normale Flugzeit abwarten.")
        let moving = movingFlights(in: app)
        XCTAssertEqual(moving.count, 0, "Reduced Motion darf keinen räumlichen Flug offen lassen.")
        attachScreenshot(of: app, named: "transcript-deal-stage3-reduced-eight-contact")
    }

    @MainActor
    func testSkipCancelsVisibleTranscriptWithoutLateContactWrite() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = localizedArguments(["-transcriptDealQA", "-coachOff", "-players=4"])
        app.launch()

        let presentation = app.descendants(matching: .any)
            .matching(identifier: "phase1.presentation").firstMatch
        XCTAssertTrue(presentation.waitForExistence(timeout: 3),
                      "Der Transcript-Status muss vor Skip existieren.")
        let initialValue = presentation.value as? String ?? ""
        let total = initialValue.split(separator: "/").last.map(String.init) ?? ""
        XCTAssertFalse(total.isEmpty, "Der Transcript-Status muss die Gesamtzahl benennen.")

        let firstFlight = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phase1.deal.transcript.flight.")
        ).firstMatch
        XCTAssertTrue(firstFlight.waitForExistence(timeout: 4),
                      "Vor Skip muss ein echter Transcript-Flug sichtbar sein.")

        let board = app.images.matching(identifier: "table.world.phase1.board").firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 3), "Der Skip-Tap braucht das echte Board.")
        board.tap()

        let completed = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND value BEGINSWITH %@",
                        "phase1.presentation", "deal \(total)/\(total)")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3),
                      "Skip muss die Präsentation atomar abschließen.")
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertEqual(movingFlights(in: app).count, 0,
                       "Ein abgebrochener View-Task darf keinen Flug wiederbeleben.")
        XCTAssertTrue(completed.exists,
                      "Ein später Transcript-Callback darf den abgeschlossenen State nicht zurückschreiben.")
    }

    @MainActor
    private func dealStatus(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "phase1.presentation").firstMatch
    }

    @MainActor
    private func waitForDealCount(
        _ count: Int,
        status: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            XCTAssertLessThanOrEqual(
                movingFlights(in: app).count,
                2,
                "Flug und Settle zusammen dürfen nie mehr als zwei Karten bewegen."
            )
            if landedCount(from: status) >= count { return }
            Thread.sleep(forTimeInterval: 0.025)
        }
        let finalValue = status.value as? String ?? "<kein Wert>"
        XCTFail("Dealstatus \(count) wurde nicht rechtzeitig erreicht; letzter Wert: \(finalValue)")
    }

    @MainActor
    private func landedCount(from status: XCUIElement) -> Int {
        let value = status.value as? String ?? ""
        let countText = value
            .replacingOccurrences(of: "deal ", with: "")
            .split(separator: "/")
            .first
        return countText.flatMap { Int($0) } ?? -1
    }

    @MainActor
    private func assertAtMostTwoMovingCards(in app: XCUIApplication, samples: Int) {
        for _ in 0..<samples {
            XCTAssertLessThanOrEqual(
                movingFlights(in: app).count,
                2,
                "Flug und Settle zusammen dürfen nie mehr als zwei Karten bewegen."
            )
            Thread.sleep(forTimeInterval: 0.025)
        }
    }

    @MainActor
    private func movingFlights(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND (value BEGINSWITH %@ OR value BEGINSWITH %@)",
                "phase1.deal.transcript.flight.", "inFlight", "settling"
            )
        )
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        app.activate()
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
}
