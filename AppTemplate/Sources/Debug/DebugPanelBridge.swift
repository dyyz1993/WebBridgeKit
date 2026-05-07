import UIKit
import WebBridgeKit

public class DebugPanelBridge {

    public static let shared = DebugPanelBridge()

    private init() {}

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
        vc.view.backgroundColor = ThemeColors.current.background
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = ThemeColors.current.surface
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
        vc.view.backgroundColor = ThemeColors.current.background
        let label = UILabel()
        label.text = "Push Token Management\n\nBark Key: test_key\nWebhook: port 8765\n\nUse the Message tab to send test pushes."
        label.textAlignment = .center
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.textSecondary
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
        vc.view.backgroundColor = ThemeColors.current.background
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = ThemeColors.current.surface
        textView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalTo(vc.view.safeAreaLayoutGuide).inset(16)
        }
        textView.text = """
        AI HTTP Server

        Port: 8765
        Status: Running (local)

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
