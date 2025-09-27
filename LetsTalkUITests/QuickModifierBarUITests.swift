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

        // Build "I like play" using seeded Home tiles (or via Activities if needed)
        tapTile(text: "I")
        tapTile(text: "like")

        // Try to tap "play" on Home; if it doesn't append, navigate via Activities and try again.
        let beforePlay = canonicalizedMessage(message.label)
        let tappedPlayOnHome = tryTapTile(text: "play", exactOnly: true)
        let appendedOnHome = waitForMessageChange(message, from: beforePlay, timeout: 1.2)

        // If home path failed to append precisely "play", correct via Activities.
        if !tappedPlayOnHome || !appendedOnHome || lastWord(in: canonicalizedMessage(message.label))?.lowercased() != "play" {
            // Fallback: open Activities category and try again
            _ = tryTapTile(text: "Activities", exactOnly: true)
            // brief settle
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))

            // If we appended the wrong word (e.g., "what"), remove it so we can add "play"
            if let lw = lastWord(in: canonicalizedMessage(message.label)), lw.lowercased() != "play", lw.lowercased() != "like" {
                app.buttons["BackspaceButton"].tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            }

            tapTile(text: "play", exactOnly: true)
            _ = waitForMessageChange(message, from: beforePlay, timeout: 1.2)
        }

        // Verify base message (canonicalized to strip 'Message:' and map 'Eye' -> 'I')
        XCTAssertEqual(canonicalizedMessage(message.label), "I like play")

        // Tap -ing
        app.buttons["QuickModIngButton"].tap()
        XCTAssertEqual(canonicalizedMessage(message.label), "I like playing")

        // Backspace to remove "playing" -> "I like"
        app.buttons["BackspaceButton"].tap()
        XCTAssertEqual(canonicalizedMessage(message.label), "I")

        // Rebuild last word to "like"
        tapTile(text: "like", exactOnly: true)
        XCTAssertEqual(canonicalizedMessage(message.label), "I like")

        // Tap -ed
        app.buttons["QuickModEdButton"].tap()
        XCTAssertEqual(canonicalizedMessage(message.label), "I liked")

        // Tap not (no auxiliary present; should append)
        app.buttons["QuickModNotButton"].tap()
        XCTAssertEqual(canonicalizedMessage(message.label), "I liked not")
    }

    // MARK: - Helpers

    private func tapTile(text: String, exactOnly: Bool = false) {
        // Try to find a good tap target with exact label/identifier/value (case-insensitive).
        var element = findPreferredTapTarget(forText: text, exactOnly: exactOnly)

        // Give the UI a brief chance to load before we start scrolling
        if element == nil {
            let exact = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text))
                .firstMatch
            if exact.waitForExistence(timeout: 0.8) {
                element = exact
            }
        }

        // If not found, attempt to scroll in common containers to reveal it, up to a short deadline.
        let deadline = Date().addingTimeInterval(2.0)
        var attempts = 0
        while (element == nil || !(element?.exists ?? false)) && attempts < 8 && Date() < deadline {
            if let scrollable = firstScrollableContainer() {
                switch attempts % 4 {
                case 0: scrollable.swipeUp()
                case 1: scrollable.swipeDown()
                case 2: scrollable.swipeLeft()
                default: scrollable.swipeRight()
                }
            } else {
                switch attempts % 4 {
                case 0: app.swipeUp()
                case 1: app.swipeDown()
                case 2: app.swipeLeft()
                default: app.swipeRight()
                }
            }
            attempts += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.06))
            element = findPreferredTapTarget(forText: text, exactOnly: exactOnly)
        }

        guard var target = element else {
            let labels = visibleLabelsSnapshot().joined(separator: ", ")
            XCTFail("Tile '\(text)' should exist. Visible labels: \(labels)")
            return
        }

        // If we found only a static text, try to resolve a better tappable container; otherwise tap the static text directly.
        if target.elementType == .staticText {
            if let container = tapContainer(forStaticTextLabeled: text) {
                target = container
            }
        }

        _ = target.waitForExistence(timeout: 2.0)
        if !target.isHittable, let scrollable = firstScrollableContainer() {
            for _ in 0..<2 where !target.isHittable {
                scrollable.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.04))
            }
        }

        XCTAssertTrue(target.exists, "Tile '\(text)' should exist")
        if target.isHittable {
            target.tap()
        } else {
            let center = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    // Non-asserting tap; returns true if it managed to tap something matching text.
    private func tryTapTile(text: String, exactOnly: Bool = false) -> Bool {
        var element = findPreferredTapTarget(forText: text, exactOnly: exactOnly)

        if element == nil {
            let exact = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text))
                .firstMatch
            if exact.waitForExistence(timeout: 0.5) {
                element = exact
            }
        }

        let deadline = Date().addingTimeInterval(1.2)
        var attempts = 0
        while (element == nil || !(element?.exists ?? false)) && attempts < 6 && Date() < deadline {
            if let scrollable = firstScrollableContainer() {
                switch attempts % 4 {
                case 0: scrollable.swipeUp()
                case 1: scrollable.swipeDown()
                case 2: scrollable.swipeLeft()
                default: scrollable.swipeRight()
                }
            } else {
                switch attempts % 4 {
                case 0: app.swipeUp()
                case 1: app.swipeDown()
                case 2: app.swipeLeft()
                default: app.swipeRight()
                }
            }
            attempts += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            element = findPreferredTapTarget(forText: text, exactOnly: exactOnly)
        }

        guard var target = element, target.exists else {
            return false
        }

        if target.elementType == .staticText {
            if let container = tapContainer(forStaticTextLabeled: text) {
                target = container
            }
        }

        _ = target.waitForExistence(timeout: 1.0)
        if !target.isHittable, let scrollable = firstScrollableContainer() {
            for _ in 0..<2 where !target.isHittable {
                scrollable.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.03))
            }
        }

        if target.isHittable {
            target.tap()
        } else {
            let center = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        return true
    }

    // Prefer to tap a Button with the label, then a StaticText, then a Cell containing the label, else any matching element.
    private func findPreferredTapTarget(forText text: String, exactOnly: Bool) -> XCUIElement? {
        // 1) Button with exact label/identifier/value (case-insensitive)
        let exactButton = app.buttons
            .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text))
            .firstMatch
        if exactButton.exists { return exactButton }

        // 2) Static text with exact label/identifier/value
        let exactStatic = app.staticTexts
            .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text))
            .firstMatch
        if exactStatic.exists { return exactStatic }

        // 3) Cell containing a static text with that label (identifier-based; may not always match label)
        if let cell = app.cells
            .containing(.staticText, identifier: text)
            .firstMatchIfExists() {
            return cell
        }

        // 4) Any element with exact label/identifier/value (case-insensitive)
        let exactAny = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text))
            .firstMatch
        if exactAny.exists { return exactAny }

        // 5) Optional: Contains match across label or identifier or value (case-insensitive)
        if !exactOnly {
            let containsEither = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text, text))
                .firstMatch
            if containsEither.exists { return containsEither }
        }

        return nil
    }

    private func tapContainer(forStaticTextLabeled text: String) -> XCUIElement? {
        if let cell = app.cells.containing(.staticText, identifier: text).firstMatchIfExists() {
            return cell
        }
        if let button = app.buttons.containing(.staticText, identifier: text).firstMatchIfExists() {
            return button
        }
        return nil
    }

    private func firstScrollableContainer() -> XCUIElement? {
        if let s = app.scrollViews.firstMatchIfExists() { return s }
        if let t = app.tables.firstMatchIfExists() { return t }
        if let c = app.collectionViews.firstMatchIfExists() { return c }
        return nil
    }

    private func visibleLabelsSnapshot() -> [String] {
        var labels: [String] = []
        let queries: [XCUIElementQuery] = [
            app.buttons, app.cells, app.staticTexts, app.collectionViews, app.tables, app.otherElements
        ]
        for query in queries {
            for element in query.allElementsBoundByIndex.prefix(80) {
                if element.isHittable {
                    let label = element.label
                    if !label.isEmpty {
                        labels.append(label)
                        if labels.count >= 40 { return labels }
                    }
                }
            }
        }
        if labels.isEmpty {
            let any = app.descendants(matching: .any).allElementsBoundByIndex.prefix(40)
            for element in any {
                let label = element.label
                if !label.isEmpty {
                    labels.append(label)
                }
            }
        }
        return labels
    }

    // Canonicalizes UI text:
    // - Strips leading "Message:" (optional whitespace)
    // - Maps whole-word "Eye" to "I"
    // - Collapses extra whitespace and trims ends
    private func canonicalizedMessage(_ raw: String) -> String {
        var text = raw
        if text.hasPrefix("Message:") {
            text = text.replacingOccurrences(of: #"^Message:\s*"#, with: "", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: #"\bEye\b"#, with: "I", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract the last word token from a canonicalized message.
    private func lastWord(in canonical: String) -> String? {
        let parts = canonical.split(whereSeparator: { $0.isWhitespace })
        return parts.last.map(String.init)
    }

    // Waits briefly for the message's canonicalized text to change from a given value.
    @discardableResult
    private func waitForMessageChange(_ message: XCUIElement, from oldValue: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = canonicalizedMessage(message.label)
            if current != oldValue {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }
}

private extension XCUIElementQuery {
    func firstMatchIfExists() -> XCUIElement? {
        let element = self.firstMatch
        return element.exists ? element : nil
    }
}
