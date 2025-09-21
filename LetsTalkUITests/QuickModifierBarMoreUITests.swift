// QuickModifierBarMoreUITests.swift
import XCTest

final class QuickModifierBarMoreUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Hint to app to avoid heavy audio session setup (Speaker checks this)
        app.launchArguments.append("UITest")
        app.launch()
    }

    func testThirdSPuralAndPronouns() {
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0), "Message text should exist")

        // Ensure clean state
        clearMessageIfNeeded(message)

        // 1) 3rd‑s: Build "I like" -> tap 3rd‑s -> "I likes"
        tapTile(text: "I")
        tapTile(text: "like")
        XCTAssertEqual(message.label, "I like")
        app.buttons["QuickMod3rdSButton"].tap()
        XCTAssertEqual(message.label, "I likes")

        // Clear
        tapIfExists(app.buttons["ClearButton"])
        XCTAssertEqual(message.label, "", "Message should be cleared")

        // 2) Plural: Navigate to People, tap "mom", then Plural -> "moms"
        tapTile(text: "People") // link tile on Home
        tapTile(text: "mom")
        XCTAssertEqual(message.label, "mom")
        app.buttons["QuickModPluralButton"].tap()
        XCTAssertEqual(message.label, "moms")

        // Clear
        tapIfExists(app.buttons["ClearButton"])
        XCTAssertEqual(message.label, "", "Message should be cleared")

        // 3) Pronouns sheet: Start with "I", open sheet, choose "me" -> "me"
        tapTile(text: "I")
        XCTAssertEqual(message.label, "I")
        app.buttons["QuickModPronounsButton"].tap()

        // The sheet lists pronoun options as buttons with their text.
        let meOption = app.buttons["me"]
        XCTAssertTrue(meOption.waitForExistence(timeout: 3.0), "Pronoun option 'me' should be present")
        meOption.tap()

        XCTAssertEqual(message.label, "me")
    }

    // MARK: - Helpers

    private func tapTile(text: String) {
        // Tiles are buttons with their text as the label
        let button = app.buttons.matching(NSPredicate(format: "label == %@", text)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5.0), "Tile '\(text)' should exist")
        button.tap()
    }

    private func clearMessageIfNeeded(_ message: XCUIElement) {
        if message.label.isEmpty { return }
        tapIfExists(app.buttons["ClearButton"])
        // If a confirmation dialog appears, confirm Clear
        let clearAction = app.buttons["Clear"]
        if clearAction.waitForExistence(timeout: 1.0) {
            clearAction.tap()
        }
        // Wait for empty
        _ = message.waitForExistence(timeout: 1.0)
        XCTAssertEqual(message.label, "", "Message should be empty after clear")
    }

    private func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 2.0) {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
        }
    }
}
