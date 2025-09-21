// QuickModifierBarUITests.swift
import XCTest

final class QuickModifierBarUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Let Speaker skip heavy audio session work during UI tests
        app.launchArguments.append("UITest")
        app.launch()
    }

    func testIngEdNotFlow() {
        // Ensure SentenceBar is visible
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0), "Message text should exist")

        // Build "I like play" using seeded Home tiles
        tapTile(text: "I")
        tapTile(text: "like")
        tapTile(text: "play")

        // Verify base message
        XCTAssertEqual(message.label, "I like play")

        // Tap -ing
        app.buttons["QuickModIngButton"].tap()
        XCTAssertEqual(message.label, "I like playing")

        // Backspace to remove "playing" -> "I like"
        app.buttons["BackspaceButton"].tap()
        XCTAssertEqual(message.label, "I")

        // Rebuild last word to "like"
        tapTile(text: "like")
        XCTAssertEqual(message.label, "I like")

        // Tap -ed
        app.buttons["QuickModEdButton"].tap()
        XCTAssertEqual(message.label, "I liked")

        // Tap not (no auxiliary present; should append)
        app.buttons["QuickModNotButton"].tap()
        XCTAssertEqual(message.label, "I liked not")
    }

    // MARK: - Helpers

    private func tapTile(text: String) {
        let tile = app.buttons.matching(NSPredicate(format: "label == %@", text)).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 3.0), "Tile '\(text)' should exist")
        tile.tap()
    }
}
