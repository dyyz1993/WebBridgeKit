import UIKit

public class DebugTrigger {

    public static let shared = DebugTrigger()

    public var shakeEnabled = true

    private var isShowing = false

    private init() {}

    public func setup(window: UIWindow?) {
        applicationSupportsShake = true
    }

    public func showDebugPanel(from viewController: UIViewController?) {
        guard !isShowing else { return }
        guard let vc = viewController ?? topViewController() else { return }

        isShowing = true
        let debugPanel = DebugPanelViewController()
        let nav = UINavigationController(rootViewController: debugPanel)
        nav.modalPresentationStyle = .fullScreen

        debugPanel.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(dismissDebugPanel)
        )

        objc_setAssociatedObject(nav, &AssociatedKeys.debugPanel, self, .OBJC_ASSOCIATION_RETAIN)

        vc.present(nav, animated: true) { [weak self] in
            self?.isShowing = false
        }
    }

    @objc private func dismissDebugPanel() {
        if let rootVC = topViewController()?.presentedViewController {
            rootVC.dismiss(animated: true)
        }
    }

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

    private var applicationSupportsShake = false
}

private struct AssociatedKeys {
    nonisolated(unsafe) static var debugPanel = "debugPanel"
}
