//
//  DebugPanel.swift
//  WebBridgeKit
//

import UIKit

/// 统一的调试面板入口 - 财布所有调试功能的界面
/// 基于 Phase 2 的 Handler Registry，自动发现所有 Handler 和自动生成调试表单
public class DebugPanel: NSObject {
    
    public static let shared = DebugPanel()
    
    // MARK: - UI Components
    private var currentVC: UIViewController?
    
    // MARK: - Properties
    public var isShowing: Bool = false
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 显示调试面板
    /// - Parameter viewController: 从哪个视图控制器显示
    public func show(from viewController: UIViewController?) {
        guard !isShowing else { return }
        guard let vc = viewController ?? topViewController() else { return }
        
        isShowing = true
        
        let debugPanelVC = DebugPanelViewController()
        let nav = UINavigationController(rootViewController: debugPanelVC)
        nav.modalPresentationStyle = .fullScreen
        
        debugPanelVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "✕ Close",
            style: .plain,
            target: self,
            action: #selector(dismissDebugPanel)
        )
        
        vc.present(nav, animated: true) { [weak self] in
            self?.isShowing = false
        }
    }
    
    @objc private func dismissDebugPanel() {
        if let rootVC = topViewController()?.presentedViewController {
            rootVC.dismiss(animated: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let root = scene?.windows.first?.rootViewController
        return getTopViewController(from: root)
    }
    
    private func getTopViewController(from vc: UIViewController?) -> UIViewController? {
        guard let vc = vc else { return nil }
        if let presented = vc.presentedViewController {
            return getTopViewController(from: presented)
        }
        if let nav = vc as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return getTopViewController(from: tab.selectedViewController)
        }
        return vc
    }
}

/// 调试面板视图控制器
public class DebugPanelViewController: UIViewController {
    
    public static let shared = DebugPanelViewController()
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .systemBackground
        return sv
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()
    
    private lazy var mainButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("主页", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(showMain), for: .touchUpInside)
        return btn
    }()
    
    private lazy var logsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("日志", for: .normal)
        btn.backgroundColor = .systemGreen
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(showLogs), for: .touchUpInside)
        return btn
    }()
    
    private lazy var diagnosticsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("诊断", for: .normal)
        btn.backgroundColor = .systemOrange
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(showDiagnostics), for: .touchUpInside)
        return btn
    }()
    
    private lazy var settingsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("设置", for: .normal)
        btn.backgroundColor = .systemPurple
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        return btn
    }()
    
    private lazy var infoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("环境", for: .normal)
        btn.backgroundColor = .systemGray
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(showInfo), for: .touchUpInside)
        return btn
    }()
    
    // MARK: - Lifecycle
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        title = "🧩 Debug Panel"
        view.backgroundColor = .systemBackground
        
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        let stackView = UIStackView(arrangedSubviews: [
            mainButton,
            logsButton,
            diagnosticsButton,
            settingsButton,
            infoButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        
        contentView.addSubview(stackView)
        
        // Layout
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100)
            make.left.right.equalToSuperview().inset(32)
            make.height.equalTo(320)
        }
        
        [mainButton, logsButton, diagnosticsButton, settingsButton, infoButton].forEach { button in
            button.snp.makeConstraints { make in
                make.height.equalTo(56)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func showMain() {
        if let vc = currentVC as? WebBrowserViewController {
            vc.debugPanelDidShow = true
        }
        dismiss(animated: true)
    }
    
    @objc private func showLogs() {
        let logViewer = LogViewerViewController()
        navigationController?.pushViewController(logViewer, animated: true)
    }
    
    @objc private func showDiagnostics() {
        let diagnostic = DiagnosticViewController()
        navigationController?.pushViewController(diagnostic, animated: true)
    }
    
    @objc private func showSettings() {
        let handlerList = HandlerListViewController()
        navigationController?.pushViewController(handlerList, animated: true)
    }
    
    @objc private func showInfo() {
        let environment = EnvironmentViewController()
        navigationController?.pushViewController(environment, animated: true)
    }
}

// MARK: - WebBrowserViewController Extension

extension WebBrowserViewController {
    var debugPanelDidShow: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.debugPanelDidShow) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.debugPanelDidShow, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

private struct AssociatedKeys {
    nonisolated(unsafe) static var debugPanelDidShow = "debugPanelDidShow"
}
