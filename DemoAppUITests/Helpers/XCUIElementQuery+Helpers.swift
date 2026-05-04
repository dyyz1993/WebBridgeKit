import XCTest

extension XCUIElementQuery {
    // Find element by accessibility identifier
    func element(identifier: String) -> XCUIElement {
        return self[identifier]
    }

    // Find button by accessibility identifier
    func button(identifier: String) -> XCUIElement {
        return self.buttons[identifier]
    }

    // Find text field by accessibility identifier
    func textField(identifier: String) -> XCUIElement {
        return self.textFields[identifier]
    }
}
