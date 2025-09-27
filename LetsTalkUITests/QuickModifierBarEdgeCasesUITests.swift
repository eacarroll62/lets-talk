// QuickModifierBarEdgeCasesUITests.swift
import XCTest

final class QuickModifierBarEdgeCasesUITests: BaseUITestCase {

    func testVerbIngAndEdIrregulars() {
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0), "Message text should exist")
        clearMessageIfNeeded(message)

        // Build: "I run"
        tapTile(text: "I", exactOnly: true)
        // Try to obtain "run" either on home or via Activities/Sports if needed
        if !tryTapTile(text: "run", exactOnly: true) {
            // Best-effort navigate then try again
            _ = tryTapTile(text: "Activities", exactOnly: true)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            tapTile(text: "run", exactOnly: true)
        }

        // Sanity
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("run"))

        // Apply -ing => "I running"
        app.buttons["QuickModIngButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("running"), "Expected gerund 'running'")

        // Backspace removes the morpheme (back to 'run' or 'I')
        app.buttons["BackspaceButton"].tap()
        let afterBackspace = canonicalizedMessage(message.label).lowercased()
        XCTAssertTrue(afterBackspace == "i" || afterBackspace.hasSuffix("run"))

        // Ensure we have "run" as last token again
        if !afterBackspace.hasSuffix("run") {
            tapTile(text: "run", exactOnly: true)
        }
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("run"))

        // Apply -ed; expect irregular "ran" if supported, otherwise tolerate "runned"
        app.buttons["QuickModEdButton"].tap()
        let past = canonicalizedMessage(message.label).lowercased()
        XCTAssertTrue(
            past.hasSuffix("ran") || past.hasSuffix("runned"),
            "Expected irregular 'ran' or fallback 'runned'; got '\(past)'"
        )
    }

    func testThirdPersonSingularForms() {
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0))
        clearMessageIfNeeded(message)

        // like -> likes
        tapTile(text: "I", exactOnly: true)
        tapTile(text: "like", exactOnly: true)
        app.buttons["QuickMod3rdSButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("likes"))

        clearMessageIfNeeded(message)

        // go -> goes
        tapTile(text: "I", exactOnly: true)
        if !tryTapTile(text: "go", exactOnly: true) {
            _ = tryTapTile(text: "Activities", exactOnly: true)
            tapTile(text: "go", exactOnly: true)
        }
        app.buttons["QuickMod3rdSButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("goes"))

        clearMessageIfNeeded(message)

        // try -> tries
        tapTile(text: "I", exactOnly: true)
        if !tryTapTile(text: "try", exactOnly: true) {
            _ = tryTapTile(text: "Activities", exactOnly: true)
            tapTile(text: "try", exactOnly: true)
        }
        app.buttons["QuickMod3rdSButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("tries"))

        clearMessageIfNeeded(message)

        // watch -> watches (es)
        tapTile(text: "I", exactOnly: true)
        if !tryTapTile(text: "watch", exactOnly: true) {
            _ = tryTapTile(text: "Activities", exactOnly: true)
            tapTile(text: "watch", exactOnly: true)
        }
        app.buttons["QuickMod3rdSButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("watches"))
    }

    func testPluralForms() {
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0))
        clearMessageIfNeeded(message)

        // baby -> babies
        if !tryTapTile(text: "baby", exactOnly: true) {
            navigateToCategory(named: "People")
            tapTile(text: "baby", exactOnly: true)
        }
        app.buttons["QuickModPluralButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("babies"))

        clearMessageIfNeeded(message)

        // bus -> buses
        if !tryTapTile(text: "bus", exactOnly: true) {
            _ = tryTapTile(text: "Activities", exactOnly: true)
            tapTile(text: "bus", exactOnly: true)
        }
        app.buttons["QuickModPluralButton"].tap()
        XCTAssertTrue(canonicalizedMessage(message.label).lowercased().hasSuffix("buses"))

        clearMessageIfNeeded(message)

        // man -> men (or tolerate mans if irregular not available)
        if !tryTapTile(text: "man", exactOnly: true) {
            navigateToCategory(named: "People")
            tapTile(text: "man", exactOnly: true)
        }
        app.buttons["QuickModPluralButton"].tap()
        let manPlural = canonicalizedMessage(message.label).lowercased()
        XCTAssertTrue(manPlural.hasSuffix("men") || manPlural.hasSuffix("mans"))

        clearMessageIfNeeded(message)

        // child -> children (or tolerate childs)
        if !tryTapTile(text: "child", exactOnly: true) {
            navigateToCategory(named: "People")
            tapTile(text: "child", exactOnly: true)
        }
        app.buttons["QuickModPluralButton"].tap()
        let childPlural = canonicalizedMessage(message.label).lowercased()
        XCTAssertTrue(childPlural.hasSuffix("children") || childPlural.hasSuffix("childs"))
    }

    func testNotWithAuxiliariesAndWithout() {
        let message = app.staticTexts["MessageText"]
        XCTAssertTrue(message.waitForExistence(timeout: 5.0))
        clearMessageIfNeeded(message)

        // Without auxiliary: I like -> Not -> I like not
        tapTile(text: "I", exactOnly: true)
        tapTile(text: "like", exactOnly: true)
        app.buttons["QuickModNotButton"].tap()
        XCTAssertEqual(canonicalizedMessage(message.label), "I like not")

        clearMessageIfNeeded(message)

        // With auxiliary: I can play -> Not -> either "I cannot play" or "I can not play"
        tapTile(text: "I", exactOnly: true)

        if !tryTapTile(text: "can", exactOnly: true) {
            // If we cannot find 'can', skip this auxiliary portion to avoid false failures
            XCTSkip("Auxiliary 'can' not available in current seed")
        }
        if !tryTapTile(text: "play", exactOnly: true) {
            _ = tryTapTile(text: "Activities", exactOnly: true)
            tapTile(text: "play", exactOnly: true)
        }
        app.buttons["QuickModNotButton"].tap()
        let negated = canonicalizedMessage(message.label).lowercased()
        XCTAssertTrue(
            negated == "i cannot play" || negated == "i can not play",
            "Expected 'I cannot play' or 'I can not play', got '\(negated)'"
        )
    }
}
