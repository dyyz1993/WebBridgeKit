import XCTest

class TokenGeneratePage: BasePage {
    
    // MARK: - UI Elements
    
    var urlPickerView: XCUIElement {
        return app.pickerWheels["tokenGenerate.urlPickerView"]
    }
    
    var durationSegmentedControl: XCUIElement {
        return app.segmentedControls["tokenGenerate.durationSegmentedControl"]
    }
    
    var generateButton: XCUIElement {
        return app.buttons["tokenGenerate.generateButton"]
    }
    
    var copyButton: XCUIElement {
        return app.buttons["tokenGenerate.copyButton"]
    }
    
    var shareButton: XCUIElement {
        return app.buttons["tokenGenerate.shareButton"]
    }
    
    var navigationBar: XCUIElement {
        return app.navigationBars["Token Generate"]
    }
    
    // MARK: - Page Verification
    
    func verifyPageLoaded() -> Bool {
        return waitForElementToAppear(generateButton, timeout: 10)
    }
    
    func verifyTokenGenerated() -> Bool {
        return copyButton.isEnabled && shareButton.isEnabled
    }
    
    // MARK: - Actions
    
    func selectURL(at index: Int) {
        let picker = app.pickerWheels.firstMatch
        if picker.exists {
            picker.adjust(toPickerWheelValue: "\(index)")
        }
    }
    
    func selectDuration(_ duration: TokenDuration) {
        // Use buttons to tap on segmented control segments
        let segmentedControl = app.segmentedControls["tokenGenerate.durationSegmentedControl"]

        switch duration {
        case .oneDay:
            if segmentedControl.buttons.count > 0 {
                segmentedControl.buttons.element(boundBy: 0).tap()
            }
        case .sevenDays:
            if segmentedControl.buttons.count > 1 {
                segmentedControl.buttons.element(boundBy: 1).tap()
            }
        case .thirtyDays:
            if segmentedControl.buttons.count > 2 {
                segmentedControl.buttons.element(boundBy: 2).tap()
            }
        case .permanent:
            if segmentedControl.buttons.count > 3 {
                segmentedControl.buttons.element(boundBy: 3).tap()
            }
        }
    }
    
    func tapGenerateButton() {
        tapElement(generateButton)
    }
    
    func tapCopyButton() {
        tapElement(copyButton)
    }
    
    func tapShareButton() {
        tapElement(shareButton)
    }
    
    // MARK: - Token Verification
    
    func waitForTokenGeneration(timeout: TimeInterval = 10) -> Bool {
        return waitForElementToAppear(copyButton, timeout: timeout)
    }
    
    /// 获取生成的口令文本
    func getTokenText() -> String? {
        // Token 通常显示在文本字段或标签中，使用特定的 accessibility identifier
        let tokenTextField = app.textFields["tokenGenerate.tokenTextField"].firstMatch
        if tokenTextField.exists {
            return tokenTextField.value as? String
        }

        // 尝试查找包含 token 格式的静态文本
        let predicate = NSPredicate(format: "label CONTAINS 'token' OR label CONTAINS '口令'")
        let tokenLabel = app.staticTexts.element(matching: predicate)
        if tokenLabel.exists {
            return tokenLabel.label
        }

        // 最后尝试查找任何包含长字符串的静态文本（token 通常较长）
        let allTexts = app.staticTexts.allElementsBoundByIndex
        for textElement in allTexts {
            let label = textElement.label
            if label.count > 20 && label.count < 100 {
                return label
            }
        }

        return nil
    }
    
    // MARK: - Enums
    
    enum TokenDuration {
        case oneDay
        case sevenDays
        case thirtyDays
        case permanent
    }
}
