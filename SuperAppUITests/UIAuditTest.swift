import XCTest

final class UIAuditTest: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
    }

    struct UIIssue {
        let severity: String
        let rule: String
        let element: String
        let detail: String
        let frame: CGRect
    }

    func auditElement(_ element: XCUIElement, issues: inout [UIIssue], path: String = "", depth: Int = 0) {
        guard depth < 8 else { return }
        let currentPath = path.isEmpty ? "\(elementTypeString(element.elementType))" : "\(path)/\(elementTypeString(element.elementType))"
        let label = element.label.isEmpty ? "" : "[\(element.label)]"
        let id = element.identifier.isEmpty ? "" : "#\(element.identifier)"
        let elementDesc = "\(currentPath)\(label)\(id)"

        let frame = element.frame

        if element.elementType == .button || element.elementType == .switch {
            if frame.height < 44 || frame.width < 44 {
                if frame.width > 0 && frame.height > 0 {
                    issues.append(UIIssue(
                        severity: "ERROR",
                        rule: "TAP_TARGET",
                        element: elementDesc,
                        detail: "Size \(Int(frame.width))x\(Int(frame.height))pt < 44x44pt minimum",
                        frame: frame
                    ))
                }
            }
        }

        if (element.elementType == .button || element.elementType == .textField || element.elementType == .textView)
            && element.identifier.isEmpty && !element.label.isEmpty {
            issues.append(UIIssue(
                severity: "WARNING",
                rule: "MISSING_ID",
                element: elementDesc,
                detail: "Interactive element lacks accessibilityIdentifier",
                frame: frame
            ))
        }

        if element.elementType == .staticText && !element.label.isEmpty && frame.width < 30 && frame.width > 0 {
            issues.append(UIIssue(
                severity: "WARNING",
                rule: "TEXT_TRUNCATION",
                element: elementDesc,
                detail: "Text width \(Int(frame.width))pt seems too narrow for \"\(element.label)\"",
                frame: frame
            ))
        }

        if element.elementType == .button && element.label.isEmpty && element.identifier.isEmpty && frame.width > 20 {
            issues.append(UIIssue(
                severity: "WARNING",
                rule: "UNLABELED_BUTTON",
                element: elementDesc,
                detail: "Button has no label and no identifier",
                frame: frame
            ))
        }

        if element.elementType == .staticText && element.label.isEmpty && frame.width > 10 && frame.height > 10 {
            issues.append(UIIssue(
                severity: "WARNING",
                rule: "EMPTY_LABEL",
                element: elementDesc,
                detail: "StaticText has empty label but visible frame",
                frame: frame
            ))
        }

        let directChildren = element.children(matching: .any)
        for i in 0..<directChildren.count {
            let child = directChildren.element(boundBy: i)
            auditElement(child, issues: &issues, path: elementDesc, depth: depth + 1)
        }
    }

    func checkOverlaps(_ element: XCUIElement, issues: inout [UIIssue], depth: Int = 0) {
        guard depth < 6 else { return }
        let children = element.children(matching: .any)
        var interactableChildren: [(desc: String, frame: CGRect, index: Int)] = []

        for i in 0..<children.count {
            let child = children.element(boundBy: i)
            let type = child.elementType
            if type == .button || type == .switch || type == .textField || type == .textView || type == .staticText {
                let label = child.label.isEmpty ? "" : "[\(child.label)]"
                let id = child.identifier.isEmpty ? "" : "#\(child.identifier)"
                let desc = "\(elementTypeString(type))\(label)\(id)"
                interactableChildren.append((desc, child.frame, i))
            }
        }

        for i in 0..<interactableChildren.count {
            for j in (i + 1)..<interactableChildren.count {
                let a = interactableChildren[i]
                let b = interactableChildren[j]
                if a.frame.intersects(b.frame) {
                    let intersection = a.frame.intersection(b.frame)
                    if intersection.width > 2 && intersection.height > 2 {
                        issues.append(UIIssue(
                            severity: "WARNING",
                            rule: "OVERLAP",
                            element: "\(a.desc) ↔ \(b.desc)",
                            detail: "Frames overlap by \(Int(intersection.width))x\(Int(intersection.height))pt",
                            frame: intersection
                        ))
                    }
                }
            }
        }

        for i in 0..<children.count {
            checkOverlaps(children.element(boundBy: i), issues: &issues, depth: depth + 1)
        }
    }

    func runAudit(page: String) {
        var issues: [UIIssue] = []
        auditElement(app, issues: &issues)
        checkOverlaps(app, issues: &issues)
        printAuditReport(page: page, issues: issues)
        dumpUITree(app, depth: 0)
    }

    func testAuditHomePage() {
        app.tabBars.buttons["首页"].tap()
        sleep(2)
        runAudit(page: "首页 (Home)")
    }

    func testAuditTestCasesTab() {
        app.tabBars.buttons["用例"].tap()
        sleep(2)
        runAudit(page: "用例 (Test Cases)")
    }

    func testAuditManageTab() {
        app.tabBars.buttons["管理"].tap()
        sleep(2)
        runAudit(page: "管理 (Manage)")
    }

    func testAuditSettingsTab() {
        app.tabBars.buttons["设置"].tap()
        sleep(2)
        runAudit(page: "设置 (Settings)")
    }

    func printAuditReport(page: String, issues: [UIIssue]) {
        let errors = issues.filter { $0.severity == "ERROR" }
        let warnings = issues.filter { $0.severity == "WARNING" }

        print("")
        print(String(repeating: "=", count: 70))
        print("UI AUDIT REPORT: \(page)")
        print(String(repeating: "=", count: 70))
        print("ERRORS: \(errors.count) | WARNINGS: \(warnings.count)")
        print("")

        if issues.isEmpty {
            print("✅ No issues found!")
        }

        for issue in issues.sorted(by: { $0.severity > $1.severity }) {
            let icon = issue.severity == "ERROR" ? "❌" : "⚠️"
            print("\(icon) [\(issue.rule)] \(issue.element)")
            print("   \(issue.detail)")
            print("   Frame: (\(Int(issue.frame.origin.x)),\(Int(issue.frame.origin.y)),\(Int(issue.frame.width)),\(Int(issue.frame.height)))")
            print("")
        }

        print(String(repeating: "=", count: 70))
        print("TOTAL: \(errors.count) errors, \(warnings.count) warnings")
        print(String(repeating: "=", count: 70))
        print("")
    }

    func dumpUITree(_ element: XCUIElement, depth: Int) {
        guard depth < 8 else { return }
        let indent = String(repeating: "  ", count: depth)
        let frame = element.frame
        let label = element.label.isEmpty ? "" : " label=\"\(element.label)\""
        let id = element.identifier.isEmpty ? "" : " id=\"\(element.identifier)\""
        let valueStr: String
        if let v = element.value as? String, !v.isEmpty {
            valueStr = " value=\"\(v)\""
        } else {
            valueStr = ""
        }
        let typeName = elementTypeString(element.elementType)

        let children = element.children(matching: .any)
        let hasChildren = children.count > 0

        if hasChildren {
            print("\(indent)<\(typeName)\(label)\(id)\(valueStr) frame=\"\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))\">")
            for i in 0..<children.count {
                dumpUITree(children.element(boundBy: i), depth: depth + 1)
            }
            print("\(indent)</\(typeName)>")
        } else {
            print("\(indent)<\(typeName)\(label)\(id)\(valueStr) frame=\"\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))\"/>")
        }
    }

    private func elementTypeString(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .any: return "Any"
        case .other: return "Other"
        case .application: return "Application"
        case .group: return "Group"
        case .window: return "Window"
        case .sheet: return "Sheet"
        case .drawer: return "Drawer"
        case .alert: return "Alert"
        case .dialog: return "Dialog"
        case .button: return "Button"
        case .link: return "Link"
        case .textField: return "TextField"
        case .textView: return "TextView"
        case .searchField: return "SearchField"
        case .image: return "Image"
        case .staticText: return "StaticText"
        case .table: return "Table"
        case .tableRow: return "TableRow"
        case .tableColumn: return "TableColumn"
        case .scrollView: return "ScrollView"
        case .scrollBar: return "ScrollBar"
        case .pageIndicator: return "PageIndicator"
        case .progressIndicator: return "ProgressIndicator"
        case .activityIndicator: return "ActivityIndicator"
        case .segmentedControl: return "SegmentedControl"
        case .slider: return "Slider"
        case .switch: return "Switch"
        case .toggle: return "Toggle"
        case .tabBar: return "TabBar"
        case .tab: return "Tab"
        case .picker: return "Picker"
        case .pickerWheel: return "PickerWheel"
        case .keyboard: return "Keyboard"
        case .key: return "Key"
        case .navigationBar: return "NavigationBar"
        case .menu: return "Menu"
        case .menuItem: return "MenuItem"
        case .toolbar: return "Toolbar"
        case .statusBar: return "StatusBar"
        case .cell: return "Cell"
        case .collectionView: return "CollectionView"
        case .icon: return "Icon"
        case .checkBox: return "CheckBox"
        case .radioButton: return "RadioButton"
        case .radioGroup: return "RadioGroup"
        case .datePicker: return "DatePicker"
        case .stepper: return "Stepper"
        case .incrementArrow: return "IncrementArrow"
        case .decrementArrow: return "DecrementArrow"
        case .popover: return "Popover"
        case .handle: return "Handle"
        case .picker: return "Picker"
        case .touchBar: return "TouchBar"
        case .statusItem: return "StatusItem"
        @unknown default: return "Unknown(\(type.rawValue))"
        }
    }
}
