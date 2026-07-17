import XCTest

final class TableWorldStageUITests: XCTestCase {
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
                app.launch()
                XCUIDevice.shared.orientation = orientation
                assertWindowOrientation(orientation, in: app)

                let identifier = "table.world.\(phase).board"
                assertBoard(identifier, in: app)
                let suffix = orientation == .portrait ? "portrait" : "landscape"
                attachScreenshot(of: app, named: "poch-disc-\(phase)-\(suffix)")
                app.terminate()
            }
        }
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

    private func localizedArguments(_ arguments: [String]) -> [String] {
        arguments + ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    }
}
