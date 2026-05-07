//
//  DebugPanel.swift
//  AppTemplate
//
//  This file bridges AppTemplate to debug controllers
//  It provides a way for the Debug Panel to access debug features
//

import UIKit
import WebBridgeKit

// MARK: - Debug Panel Bridge

/// Debug Panel Bridge - 连接 AppTemplate 的调试面板与调试控制器
/// 所有基于 AppTemplate 的 App 都可以通过此桥接访问调试功能
public class DebugPanelBridge {
    
    public static let shared = DebugPanelBridge()
    
    private init() {}
    
    // MARK: - Debug Controllers
    
    /// 主页面调试控制器
    public func createMainViewController() -> UIViewController {
        // 这里可以返回 MainViewController
        // 或者创建一个占位符视图控制器
        return createPlaceholderViewController(title: "Main", message: "Main debug view")
    }
    
    /// 消息收件箱调试控制器
    public func createMessageInboxViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Message Inbox", message: "Message inbox debug view")
    }
    
    /// 清单缓存测试控制器
    public func createManifestCacheTestViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Manifest Cache Test", message: "Manifest cache testing")
    }
    
    /// 管理控制器（缓存 + 收藏）
    public func createManagementViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Management", message: "Cache + Favorites management")
    }
    
    /// API Key 管理控制器
    public func createAPIKeyManageViewController() -> UIViewController {
        return createPlaceholderViewController(title: "API Key Management", message: "API key configuration")
    }
    
    /// Token 管理控制器
    public func createTokenManageViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Token Management", message: "Token configuration")
    }
    
    /// 测试用例运行器控制器
    public func createManifestTestCasesViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Test Cases", message: "Test case runner")
    }
    
    /// 服务器配置控制器
    public func createServerConfigViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Server Config", message: "Server configuration")
    }
    
    /// 设置控制器
    public func createSettingsViewController() -> UIViewController {
        return createPlaceholderViewController(title: "Settings", message: "Application settings")
    }
    
    // MARK: - Helper Methods
    
    private func createPlaceholderViewController(title: String, message: String) -> UIViewController {
        let vc = UIViewController()
        vc.title = title
        vc.view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        
        vc.view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(32)
        }
        
        return vc
    }
}

// MARK: - Debug Panel Tab Extension

extension DebugPanelViewController {
    
    /// 显示调试页面
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

// MARK: - Debug Types

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
