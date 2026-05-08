import UIKit
import os.log

struct UIAuditTool {

    struct AuditIssue {
        let severity: String
        let rule: String
        let detail: String
        let elementPath: String
    }

    private static let logger = Logger(subsystem: "com.webbridgekit.superapp", category: "UIAudit")

    static func auditCurrentScreen() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            NSLog("[UIAudit] No key window found")
            return
        }

        var issues: [AuditIssue] = []
        var output: [String] = []

        output.append("======================================================================")
        output.append("UI AUDIT REPORT")
        output.append("======================================================================")

        dumpView(window, depth: 0, issues: &issues, path: "Window", output: &output)

        let errors = issues.filter { $0.severity == "ERROR" }
        let warnings = issues.filter { $0.severity == "WARNING" }

        output.append("----------------------------------------------------------------------")
        output.append("ISSUES: \(errors.count) errors, \(warnings.count) warnings")
        output.append("----------------------------------------------------------------------")

        for issue in issues {
            let icon = issue.severity == "ERROR" ? "ERROR" : "WARN"
            output.append("[\(icon)] [\(issue.rule)] \(issue.elementPath)")
            output.append("   \(issue.detail)")
        }

        output.append("======================================================================")
        output.append("TOTAL: \(errors.count) errors, \(warnings.count) warnings")
        output.append("======================================================================")

        let fullReport = output.joined(separator: "\n")
        NSLog("[UIAudit] %@", fullReport)

        let tempDir = NSTemporaryDirectory()
        let reportPath = (tempDir as NSString).appendingPathComponent("ui-audit-report.txt")
        try? fullReport.write(toFile: reportPath, atomically: true, encoding: .utf8)
        NSLog("[UIAudit] Report saved to: %@", reportPath)
    }

    private static func dumpView(_ view: UIView, depth: Int, issues: inout [AuditIssue], path: String, output: inout [String]) {
        guard depth < 12 else { return }

        let indent = String(repeating: "  ", count: depth)
        let frame = view.frame
        let className = String(describing: type(of: view))

        var attributes: [String] = []
        if let label = view.accessibilityLabel, !label.isEmpty {
            attributes.append("label=\"\(label)\"")
        }
        if let id = view.accessibilityIdentifier, !id.isEmpty {
            attributes.append("id=\"\(id)\"")
        }
        if view.isHidden {
            attributes.append("hidden")
        }
        if view.alpha < 1.0 {
            attributes.append("alpha=\(view.alpha)")
        }

        let attrStr = attributes.isEmpty ? "" : " \(attributes.joined(separator: " "))"

        if view.subviews.isEmpty {
            output.append("\(indent)<\(className)\(attrStr) frame=\"\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))\"/>")
        } else {
            output.append("\(indent)<\(className)\(attrStr) frame=\"\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))\">")
        }

        auditRules(view: view, path: path, issues: &issues)

        for subview in view.subviews {
            let subPath = "\(path)/\(className)"
            dumpView(subview, depth: depth + 1, issues: &issues, path: subPath, output: &output)
        }

        if !view.subviews.isEmpty {
            output.append("\(indent)</\(className)>")
        }
    }

    private static func auditRules(view: UIView, path: String, issues: inout [AuditIssue]) {
        if let button = view as? UIButton {
            if button.frame.height < 44 && button.frame.width > 0 && button.frame.height > 0 && !button.isHidden {
                issues.append(AuditIssue(
                    severity: "ERROR",
                    rule: "TAP_TARGET",
                    detail: "Button height \(Int(button.frame.height))pt < 44pt minimum. Title: \"\(button.titleLabel?.text ?? "(none)")\"",
                    elementPath: path
                ))
            }
        }

        if let label = view as? UILabel, !label.isHidden {
            if label.numberOfLines == 1 && label.preferredMaxLayoutWidth == 0 {
                let textSize = label.intrinsicContentSize
                if textSize.width > label.frame.width + 2 && label.frame.width > 0 {
                    issues.append(AuditIssue(
                        severity: "WARNING",
                        rule: "TEXT_TRUNCATION",
                        detail: "Label \"\(label.text ?? "")\" intrinsic width \(Int(textSize.width))pt > frame width \(Int(label.frame.width))pt, may be truncated",
                        elementPath: path
                    ))
                }
            }
        }

        if (view is UIButton || view is UITextField || view is UITextView || view is UISwitch)
            && view.accessibilityIdentifier == nil && !view.isHidden {
            let desc: String
            if let btn = view as? UIButton { desc = "Button \"\(btn.titleLabel?.text ?? "")\"" }
            else if let tf = view as? UITextField { desc = "TextField placeholder \"\(tf.placeholder ?? "")\"" }
            else if let sw = view as? UISwitch { desc = "Switch" }
            else { desc = "Interactive element" }

            issues.append(AuditIssue(
                severity: "WARNING",
                rule: "MISSING_A11Y_ID",
                detail: "\(desc) lacks accessibilityIdentifier",
                elementPath: path
            ))
        }
    }
}
