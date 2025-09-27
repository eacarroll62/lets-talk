// UITestHelpers.swift
import XCTest

// Base test case that launches the app with UITest arguments and provides shared helpers.
class BaseUITestCase: XCTestCase {

    // Exposed to subclasses
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Hint to app to avoid heavy audio session setup (Speaker checks this)
        app.launchArguments.append("UITest")
        app.launch()
    }

    // MARK: - Canonicalization and message helpers

    // Canonicalizes UI text:
    // - Strips leading "Message:" (optional whitespace)
    // - Maps whole-word "Eye" to "I"
    // - Collapses extra whitespace and trims ends
    func canonicalizedMessage(_ raw: String) -> String {
        var text = raw
        if text.hasPrefix("Message:") {
            text = text.replacingOccurrences(of: #"^Message:\s*"#, with: "", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: #"\bEye\b"#, with: "I", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isMessageEmpty(_ label: String) -> Bool {
        let canonical = canonicalizedMessage(label)
        let trimmed = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Message empty"
    }

    func clearMessageIfNeeded(_ message: XCUIElement) {
        if isMessageEmpty(message.label) { return }

        tapIfExists(app.buttons["ClearButton"])

        // Handle a potential confirmation as alert or action sheet
        if app.alerts.element.waitForExistence(timeout: 1.0) {
            let clearInAlert = app.alerts.buttons["Clear"].firstMatch
            if clearInAlert.exists { clearInAlert.tap() }
        } else if app.sheets.element.waitForExistence(timeout: 1.0) {
            let clearInSheet = app.sheets.buttons["Clear"].firstMatch
            if clearInSheet.exists { clearInSheet.tap() }
        } else {
            // Fallback: a plain button named "Clear" somewhere
            let clearAction = app.buttons["Clear"]
            if clearAction.waitForExistence(timeout: 1.0) {
                clearAction.tap()
            }
        }

        waitUntilMessageIsEmpty(message, timeout: 3.0)
        XCTAssertTrue(isMessageEmpty(message.label), "Message should be empty after clear")
    }

    func waitUntilMessageIsEmpty(_ message: XCUIElement, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isMessageEmpty(message.label) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    @discardableResult
    func waitForMessageChange(_ message: XCUIElement, from oldValue: String, timeout: TimeInterval) -> Bool {
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

    func lastWord(in canonical: String) -> String? {
        let parts = canonical.split(whereSeparator: { $0.isWhitespace })
        return parts.last.map(String.init)
    }

    // MARK: - Navigation helpers

    func navigateToCategory(named name: String, timeout: TimeInterval = 3.0) {
        func successDetected() -> Bool {
            if let crumb = currentBreadcrumb() {
                if crumb.range(of: name, options: .caseInsensitive) != nil { return true }
                if crumb.caseInsensitiveCompare("Home") != .orderedSame { return true }
            }
            if findPreferredTapTarget(forText: name, exactOnly: true) == nil { return true }
            return false
        }

        let start = Date()
        tapTile(text: name, exactOnly: true)
        var pollEnd = Date().addingTimeInterval(0.9)
        while Date() < pollEnd {
            if successDetected() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.06))
        }

        if let el = findPreferredTapTarget(forText: name, exactOnly: true), el.exists {
            let center = el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        pollEnd = Date().addingTimeInterval(0.9)
        while Date() < pollEnd {
            if successDetected() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.06))
        }

        if Date().timeIntervalSince(start) >= timeout {
            let labels = visibleLabelsSnapshot().joined(separator: ", ")
            XCTFail("Failed to navigate to '\(name)' within \(timeout)s. Breadcrumb: \(currentBreadcrumb() ?? "nil"). Visible labels: \(labels)")
            return
        }

        let labels = visibleLabelsSnapshot().joined(separator: ", ")
        XCTFail("Failed to navigate to '\(name)'. Breadcrumb: \(currentBreadcrumb() ?? "nil"). Visible labels: \(labels)")
    }

    func currentBreadcrumb() -> String? {
        let all = app.staticTexts.allElementsBoundByIndex
        for element in all {
            let label = element.label
            guard label.hasPrefix("Breadcrumb") else { continue }

            var remainder = label
            remainder.removeFirst("Breadcrumb".count)

            remainder = remainder.trimmingCharacters(in: .whitespaces)
            if remainder.first == ":" {
                remainder.removeFirst()
            }
            remainder = remainder.trimmingCharacters(in: .whitespaces)

            if !remainder.isEmpty {
                return remainder
            } else {
                let valueText = element.value as? String
                if let v = valueText, !v.isEmpty {
                    return v
                }
            }
        }
        return nil
    }

    // MARK: - Tap helpers

    func tapTile(text: String, exactOnly: Bool = false) {
        var element = findPreferredTapTarget(forText: text, exactOnly: exactOnly)

        if element == nil {
            let exact = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text))
                .firstMatch
            if exact.waitForExistence(timeout: 0.8) {
                element = exact
            }
        }

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
    func tryTapTile(text: String, exactOnly: Bool = false) -> Bool {
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
    func findPreferredTapTarget(forText text: String, exactOnly: Bool = false) -> XCUIElement? {
        let exactPredicate = NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR value ==[c] %@", text, text, text)

        let exactButton = app.buttons.matching(exactPredicate).firstMatch
        if exactButton.exists { return exactButton }

        let exactStatic = app.staticTexts.matching(exactPredicate).firstMatch
        if exactStatic.exists { return exactStatic }

        if let cell = app.cells.containing(.staticText, identifier: text).firstMatchIfExists() {
            return cell
        }

        let exactAny = app.descendants(matching: .any).matching(exactPredicate).firstMatch
        if exactAny.exists { return exactAny }

        if !exactOnly {
            let containsPredicate = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text, text)
            let containsEither = app.descendants(matching: .any).matching(containsPredicate).firstMatch
            if containsEither.exists { return containsEither }
        }

        return nil
    }

    func tapContainer(forStaticTextLabeled text: String) -> XCUIElement? {
        if let cell = app.cells.containing(.staticText, identifier: text).firstMatchIfExists() {
            return cell
        }
        if let button = app.buttons.containing(.staticText, identifier: text).firstMatchIfExists() {
            return button
        }
        return nil
    }

    func firstScrollableContainer() -> XCUIElement? {
        if let s = app.scrollViews.firstMatchIfExists() { return s }
        if let t = app.tables.firstMatchIfExists() { return t }
        if let c = app.collectionViews.firstMatchIfExists() { return c }
        return nil
    }

    func visibleLabelsSnapshot() -> [String] {
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

    func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 2.0) {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
        }
    }

    func normalize(_ s: String) -> String {
        var out = s.lowercased()
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        out.removeAll { ch in
            switch ch {
            case ".", ",", "!", "?", "’", "'", "“", "”", "\"", "•", "•", "·", "–", "—", "‑", "-", "_", ":", ";", "(", ")", "[", "]", "{", "}", "/", "\\", "|":
                return true
            default:
                return false
            }
        }
        return out
    }
}

private extension XCUIElementQuery {
    func firstMatchIfExists() -> XCUIElement? {
        let element = self.firstMatch
        return element.exists ? element : nil
    }
}
