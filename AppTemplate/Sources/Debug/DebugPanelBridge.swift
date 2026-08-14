import UIKit
import WebBridgeKit

public class DebugPanelBridge {

    public static let shared = DebugPanelBridge()

    private var configuration = AppTemplateConfiguration.safeDefaults

    private init() {}

    func configure(with configuration: AppTemplateConfiguration) {
        self.configuration = configuration
    }

    public func createMainViewController() -> UIViewController {
        return DiagnosticViewController()
    }

    public func createMessageInboxViewController() -> UIViewController {
        return MessageShowcaseViewController()
    }

    public func createManifestCacheTestViewController() -> UIViewController {
        return CacheShowcaseViewController()
    }

    public func createManagementViewController() -> UIViewController {
        return CacheManagementViewController()
    }

    public func createAPIKeyManageViewController() -> UIViewController {
        let vc = UIViewController()
        vc.title = "AI Tools Config"
        vc.view.backgroundColor = ThemeTokens.Color.background
        let textView = UITextView()
        textView.isEditable = false
        textView.font = ThemeTokens.Typography.monospaceBody
        textView.backgroundColor = ThemeTokens.Color.surface
        textView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalTo(vc.view.safeAreaLayoutGuide).inset(16)
        }
        let tools = BuiltinAITools.all
        textView.text = tools.map { "- \($0.name): \($0.description)" }.joined(separator: "\n\n")
        return vc
    }

    public func createTokenManageViewController() -> UIViewController {
        let vc = UIViewController()
        vc.title = "Push Token"
        vc.view.backgroundColor = ThemeTokens.Color.background
        let label = UILabel()
        let barkState = configuration.barkDeviceKey == nil ? "未配置" : "已配置（值已隐藏）"
        label.text = "Push Token Management\n\nBark: \(barkState)\nWebhook: Disabled\n\nConfigure channels explicitly in AppTemplateConfiguration."
        label.textAlignment = .center
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 0
        vc.view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(32)
        }
        return vc
    }

    public func createManifestTestCasesViewController() -> UIViewController {
        return HandlerListViewController()
    }

    public func createServerConfigViewController() -> UIViewController {
        let vc = UIViewController()
        vc.title = "AI Server"
        vc.view.backgroundColor = ThemeTokens.Color.background
        let textView = UITextView()
        textView.isEditable = false
        textView.font = ThemeTokens.Typography.monospaceBody
        textView.backgroundColor = ThemeTokens.Color.surface
        textView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalTo(vc.view.safeAreaLayoutGuide).inset(16)
        }
        let serverState: String
        if let port = configuration.localDiagnosticsPort {
            serverState = "Enabled on port \(port); startup runs asynchronously"
        } else {
            serverState = "Disabled"
        }
        textView.text = """
        AI HTTP Server

        Status: \(serverState)

        Endpoints:
          GET  /health          - Health check
          GET  /tools           - List all tools
          POST /tools/:name     - Execute tool
          POST /mcp             - MCP protocol

        Registered Tools:
        \(BuiltinAITools.all.map { "  \($0.name) [\($0.category)] - \($0.description)" }.joined(separator: "\n"))
        """
        return vc
    }

    public func createSettingsViewController() -> UIViewController {
        return ThemeShowcaseViewController()
    }
}

extension DebugPanelViewController {

    public func showDebugViewController(_ type: DebugType) {
        let viewController: UIViewController

        switch type {
        case .main:
            viewController = DebugPanelBridge.shared.createMainViewController()
        case .messageInbox:
            viewController = DebugPanelBridge.shared.createMessageInboxViewController()
        case .manifestCacheTest:
            viewController = DebugPanelBridge.shared.createManifestCacheTestViewController()
        case .management:
            viewController = DebugPanelBridge.shared.createManagementViewController()
        case .apiKeyManage:
            viewController = DebugPanelBridge.shared.createAPIKeyManageViewController()
        case .tokenManage:
            viewController = DebugPanelBridge.shared.createTokenManageViewController()
        case .manifestTestCases:
            viewController = DebugPanelBridge.shared.createManifestTestCasesViewController()
        case .serverConfig:
            viewController = DebugPanelBridge.shared.createServerConfigViewController()
        case .settings:
            viewController = DebugPanelBridge.shared.createSettingsViewController()
        }

        navigationController?.pushViewController(viewController, animated: true)
    }
}

public enum DebugType {
    case main
    case messageInbox
    case manifestCacheTest
    case management
    case apiKeyManage
    case tokenManage
    case manifestTestCases
    case serverConfig
    case settings
}
