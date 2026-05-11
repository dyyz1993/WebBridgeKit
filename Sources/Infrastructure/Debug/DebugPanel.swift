//
//  DebugPanel.swift
//  WebBridgeKit
//

import UIKit

/// 统一的调试面板入口 - 财布所有调试功能的界面
/// 基于 Phase 2 的 Handler Registry，自动发现所有 Handler 和自动生成调试表单
public class DebugPanel: NSObject {

    public static let shared = DebugPanel()

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
        sv.backgroundColor = ThemeTokens.Color.background
        return sv
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.background
        return view
    }()

    private lazy var mainButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("主页", for: .normal)
        btn.backgroundColor = ThemeTokens.Color.primary
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.addTarget(self, action: #selector(showMain), for: .touchUpInside)
        btn.accessibilityLabel = "调试主页"
        return btn
    }()

    private lazy var logsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("日志", for: .normal)
        btn.backgroundColor = ThemeTokens.Color.success
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.addTarget(self, action: #selector(showLogs), for: .touchUpInside)
        btn.accessibilityLabel = "调试日志"
        return btn
    }()

    private lazy var diagnosticsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("诊断", for: .normal)
        btn.backgroundColor = ThemeTokens.Color.warning
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.addTarget(self, action: #selector(showDiagnostics), for: .touchUpInside)
        btn.accessibilityLabel = "调试诊断"
        return btn
    }()

    private lazy var settingsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("设置", for: .normal)
        btn.backgroundColor = ThemeTokens.Color.gradientEnd
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        btn.accessibilityLabel = "调试设置"
        return btn
    }()

    private lazy var infoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("环境", for: .normal)
        btn.backgroundColor = ThemeTokens.Color.textSecondary
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.addTarget(self, action: #selector(showInfo), for: .touchUpInside)
        btn.accessibilityLabel = "调试环境信息"
        return btn
    }()

    private lazy var cacheButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("缓存管理", for: .normal)
        btn.backgroundColor = ThemeTokens.Color.info
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.addTarget(self, action: #selector(showCacheManagement), for: .touchUpInside)
        btn.accessibilityLabel = "调试缓存管理"
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
        view.backgroundColor = ThemeTokens.Color.background

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
            infoButton,
            cacheButton
        ])
        stackView.axis = .vertical
        stackView.spacing = ThemeTokens.Spacing.md
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
            make.height.equalTo(384)
        }

        [mainButton, logsButton, diagnosticsButton, settingsButton, infoButton, cacheButton].forEach { button in
            button.snp.makeConstraints { make in
                make.height.equalTo(56)
            }
        }
    }

    // MARK: - Actions

    @objc private func showMain() {
        dismiss(animated: true)
    }

    @objc private func showLogs() {
        showNotImplemented("日志查看器")
    }

    @objc private func showDiagnostics() {
        showNotImplemented("诊断工具")
    }

    @objc private func showSettings() {
        showNotImplemented("设置")
    }

    @objc private func showInfo() {
        showNotImplemented("环境信息")
    }

    @objc private func showCacheManagement() {
        let cacheVC = CacheManagementViewController()
        navigationController?.pushViewController(cacheVC, animated: true)
    }

    private func showNotImplemented(_ featureName: String) {
        let alert = UIAlertController(
            title: "功能未实现",
            message: "\(featureName) 在当前版本中不可用",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
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
