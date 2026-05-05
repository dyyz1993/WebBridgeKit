//
//  DebugPanelViewController.swift
//  AppTemplate
//

import UIKit
import WebBridgeKit

/// Debug Panel - 自动发现所有 Handler，提供一键测试、日志查看、诊断
/// 所有基于 AppTemplate 的 App 都自动拥有此面板
public class DebugPanelViewController: UITabBarController {
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        setupTabs()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTabs()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "🔧 Debug Panel"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy All",
            style: .plain,
            target: self,
            action: #selector(copyDiagnosticReport)
        )
    }
    
    private func setupTabs() {
        let handlerList = HandlerListViewController()
        handlerList.tabBarItem = UITabBarItem(title: "Handlers", image: UIImage(systemName: "square.grid.2x2"), tag: 0)
        
        let logViewer = LogViewerViewController()
        logViewer.tabBarItem = UITabBarItem(title: "Logs", image: UIImage(systemName: "doc.text"), tag: 1)
        
        let diagnostic = DiagnosticViewController()
        diagnostic.tabBarItem = UITabBarItem(title: "Diagnostic", image: UIImage(systemName: "stethoscope"), tag: 2)
        
        let environment = EnvironmentViewController()
        environment.tabBarItem = UITabBarItem(title: "Environment", image: UIImage(systemName: "info.circle"), tag: 3)
        
        viewControllers = [
            UINavigationController(rootViewController: handlerList),
            UINavigationController(rootViewController: logViewer),
            UINavigationController(rootViewController: diagnostic),
            UINavigationController(rootViewController: environment)
        ]
    }
    
    @objc private func copyDiagnosticReport() {
        let report = DiagnosticEngine.shared.generateReport()
        UIPasteboard.general.string = report
        
        let alert = UIAlertController(title: "Copied!", message: "Diagnostic report copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
