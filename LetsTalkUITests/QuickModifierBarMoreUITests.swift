// QuickModifierBarMoreUITests.swift
import XCTest

final class QuickModifierBarMoreUITests: BaseUITestCase {

    override func setUp() {
        super.setUp()
        // BaseUITestCase sets continueAfterFailure = false and launches the app with "UITest"
    }

    func testThirdSPuralAndPronouns() {
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0), "Message text should exist")

        // Ensure clean state
        clearMessageIfNeeded(message)

        // 1) 3rd‑s: Build "I like" -> tap 3rd‑s -> "I likes"
        tapTile(text: "I", exactOnly: true)
        tapTile(text: "like", exactOnly: true)
        XCTAssertEqual(canonicalizedMessage(message.label), "I like")
        app.buttons["QuickMod3rdSButton"].tap()
        XCTAssertEqual(canonicalizedMessage(message.label), "I likes")

        // Clear using helper that handles confirmations and waiting
        clearMessageIfNeeded(message)
        XCTAssertTrue(isMessageEmpty(message.label), "Message should be cleared")

        // 2) Plural: Navigate to People, tap "mom" (or synonym), then Plural -> "moms"
        navigateToCategory(named: "People")
        tapAnyOf(["mom", "mother", "mommy", "mum", "mama"])
        XCTAssertTrue(
            ["mom", "mother", "mommy", "mum", "mama"].contains(canonicalizedMessage(message.label).lowercased()),
            "Message should contain a parent noun"
        )
        app.buttons["QuickModPluralButton"].tap()
        // After pluralizing, normalize common variants to check plural
        let plural = canonicalizedMessage(message.label).lowercased()
        XCTAssertTrue(
            ["moms", "mothers", "mommies", "mums", "mamas"].contains(plural),
            "Plural should be applied; got '\(plural)'"
        )

        // Clear using helper that handles confirmations and waiting
        clearMessageIfNeeded(message)
        XCTAssertTrue(isMessageEmpty(message.label), "Message should be cleared")

        // 3) Pronouns sheet: Start with "I", open sheet, choose "me" -> "me"
        tapTile(text: "I", exactOnly: true)
        XCTAssertEqual(canonicalizedMessage(message.label), "I")
        app.buttons["QuickModPronounsButton"].tap()

        // The sheet lists pronoun options as buttons with their text.
        let meOption = app.buttons["me"]
        XCTAssertTrue(meOption.waitForExistence(timeout: 3.0), "Pronoun option 'me' should be present")
        meOption.tap()

        XCTAssertEqual(canonicalizedMessage(message.label), "me")
    }

    // MARK: - Local convenience

    // Try each candidate with a non-asserting tap; fail with a useful snapshot if none found.
    private func tapAnyOf(_ candidates: [String]) {
        for text in candidates {
            if tryTapTile(text: text, exactOnly: true) {
                return
            }
        }
        let labels = visibleLabelsSnapshot().joined(separator: ", ")
        XCTFail("None of the candidates \(candidates) were found. Visible labels: \(labels)")
    }
}
