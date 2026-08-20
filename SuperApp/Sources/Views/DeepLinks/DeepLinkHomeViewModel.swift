#if DEBUG
import Foundation
import UIKit
import WebBridgeKit

enum DeepLinkAction {
    case openTarget(URL, WebBrowserParams.DisplayMode)
    case openScheme(URL)
    case switchTab(Int)
}

struct DeepLinkTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: LucideIcon
    let targetURL: String
    let mode: WebBrowserParams.DisplayMode
    let tabIndex: Int?
}

final class DeepLinkHomeViewModel: ObservableObject {
    @Published var templates: [DeepLinkTemplate] = DeepLinkHomeViewModel.makeTemplates()
    @Published var selectedTemplateID = "open-cache-demo"
    @Published var targetURLText = "http://localhost:8081/test_resources/cache-showcase.html"
    @Published var commandToken = "demo-token"
    @Published var tabIndexText = "0"
    @Published var displayMode: WebBrowserParams.DisplayMode = .normal
    @Published var resultState: ResultPanel.State = .idle
    @Published var resultDetail = ""

    var selectedTemplate: DeepLinkTemplate? {
        templates.first { $0.id == selectedTemplateID }
    }

    var generatedOpenScheme: String {
        guard let encoded = targetURLText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "webbridgekit://open"
        }
        return "webbridgekit://open?url=\(encoded)"
    }

    var generatedCommandScheme: String {
        let token = commandToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return "webbridgekit://command/\(token.isEmpty ? "demo-token" : token)"
    }

    var generatedTabScheme: String {
        let index = Int(tabIndexText) ?? 0
        return "webbridgekit://tab?index=\(max(0, min(index, AppTab.allCases.count - 1)))"
    }

    var serviceItems: [AppShellStatusItem] {
        [
            AppShellStatusItem(title: "Scheme", value: "webbridgekit", tone: .success),
            AppShellStatusItem(title: "Target", value: URL(string: targetURLText)?.scheme ?? "invalid", tone: URL(string: targetURLText) == nil ? .warning : .neutral),
            AppShellStatusItem(title: "Mode", value: modeTitle(displayMode), tone: .neutral)
        ]
    }

    func selectTemplate(_ template: DeepLinkTemplate) {
        selectedTemplateID = template.id
        targetURLText = template.targetURL
        displayMode = template.mode
        if let tabIndex = template.tabIndex {
            tabIndexText = "\(tabIndex)"
        }
        resultState = .idle
        resultDetail = ""
    }

    func validateOpenScheme() {
        guard let targetURL = URL(string: targetURLText), targetURL.scheme != nil else {
            resultState = .failure("目标 URL 不合法")
            resultDetail = targetURLText
            return
        }

        guard URL(string: generatedOpenScheme) != nil else {
            resultState = .failure("生成的 webbridgekit://open 链接不合法")
            resultDetail = generatedOpenScheme
            return
        }

        resultState = .success("协议链接合法，可以复制或试打开")
        resultDetail = """
        {
          "scheme": "webbridgekit",
          "host": "open",
          "target": "\(targetURL.absoluteString)",
          "mode": "\(modeTitle(displayMode))"
        }
        """
    }

    func openTargetAction() -> DeepLinkAction? {
        guard let targetURL = URL(string: targetURLText), targetURL.scheme != nil else {
            resultState = .failure("目标 URL 不合法")
            resultDetail = targetURLText
            return nil
        }
        resultState = .success("准备打开目标页面")
        resultDetail = targetURL.absoluteString
        return .openTarget(targetURL, displayMode)
    }

    func openSchemeAction() -> DeepLinkAction? {
        guard let url = URL(string: generatedOpenScheme) else {
            resultState = .failure("协议链接不合法")
            resultDetail = generatedOpenScheme
            return nil
        }
        resultState = .success("准备触发系统协议链接")
        resultDetail = url.absoluteString
        return .openScheme(url)
    }

    func switchTabAction() -> DeepLinkAction {
        let index = Int(tabIndexText) ?? 0
        let normalized = max(0, min(index, AppTab.allCases.count - 1))
        resultState = .success("准备切换到 Tab \(normalized)")
        resultDetail = generatedTabScheme
        return .switchTab(normalized)
    }

    func copyOpenScheme() {
        UIPasteboard.general.string = generatedOpenScheme
        resultState = .success("open 协议链接已复制")
        resultDetail = generatedOpenScheme
    }

    func copyCommandScheme() {
        UIPasteboard.general.string = generatedCommandScheme
        resultState = .success("command 协议链接已复制")
        resultDetail = generatedCommandScheme
    }

    func copyTabScheme() {
        UIPasteboard.general.string = generatedTabScheme
        resultState = .success("tab 协议链接已复制")
        resultDetail = generatedTabScheme
    }

    func copyResult() {
        UIPasteboard.general.string = resultDetail.isEmpty ? generatedOpenScheme : resultDetail
    }

    func modeTitle(_ mode: WebBrowserParams.DisplayMode) -> String {
        switch mode {
        case .normal:
            return "normal"
        case .immersive:
            return "immersive"
        case .modal:
            return "modal"
        @unknown default:
            return "unknown"
        }
    }

    private static func makeTemplates() -> [DeepLinkTemplate] {
        [
            DeepLinkTemplate(
                id: "open-cache-demo",
                title: "缓存测试页",
                subtitle: "打开本地静态服务中的缓存 demo",
                icon: .hardDrive,
                targetURL: "http://localhost:8081/test_resources/cache-showcase.html",
                mode: .normal,
                tabIndex: nil
            ),
            DeepLinkTemplate(
                id: "open-remote",
                title: "远程网页",
                subtitle: "验证普通 URL 参数解析",
                icon: .globe,
                targetURL: "https://example.com",
                mode: .normal,
                tabIndex: nil
            ),
            DeepLinkTemplate(
                id: "open-modal",
                title: "浮层网页",
                subtitle: "用 modal 模式验证弹层打开",
                icon: .appBadge,
                targetURL: "https://example.com",
                mode: .modal,
                tabIndex: nil
            ),
            DeepLinkTemplate(
                id: "tab-settings",
                title: "切到 Settings",
                subtitle: "生成 webbridgekit://tab?index=3，Debug/Links 已收纳到这里",
                icon: .settings,
                targetURL: "http://localhost:8081/test_resources/cache-demo.html",
                mode: .normal,
                tabIndex: 3
            )
        ]
    }
}

#endif
