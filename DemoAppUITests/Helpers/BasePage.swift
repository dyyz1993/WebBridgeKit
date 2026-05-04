import XCTest

class BasePage {

    let app: XCUIApplication
    let timeout: TimeInterval = 10.0

    init(app: XCUIApplication = XCUIApplication()) {
        self.app = app
    }

    // MARK: - Wait Methods

    func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    // MARK: - Tap Methods

    func tapElement(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element does not exist: \(element)")
        element.tap()
    }

    func tapElementIfExists(_ element: XCUIElement) -> Bool {
        if element.exists {
            element.tap()
            return true
        }
        return false
    }

    // MARK: - Text Input Methods

    func typeText(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element does not exist: \(element)")
        element.tap()
        element.typeText(text)
    }

    func clearAndTypeText(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element does not exist: \(element)")

        let currentValue = element.value as? String ?? ""
        if !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.tap()
            element.typeText(deleteString)
        }

        element.typeText(text)
    }

    // MARK: - Verification Methods

    func verifyElementExists(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return waitForElementToAppear(element, timeout: timeout)
    }

    func verifyElementEnabled(_ element: XCUIElement) -> Bool {
        return element.isEnabled && element.exists
    }

    func verifyElementContainsText(_ element: XCUIElement, text: String) -> Bool {
        guard element.exists else { return false }
        return element.label.contains(text) || (element.value as? String)?.contains(text) ?? false
    }
}
