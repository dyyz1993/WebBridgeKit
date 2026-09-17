import Foundation
import UIKit
import WebBridgeKit

/// The single entry for opening a `drel://app?...` external launch link from
/// any surface (open-url handoff, push message URL, message detail links).
/// Only registered (gateway-signed) apps open; everything else fails closed
/// with an explanation alert and never touches a browser.
enum DrelExternalAppLinkOpener {

    /// Returns true when the URL was recognized as a drel app link (opened or
    /// fail-closed). False means the caller should keep its normal handling.
    @discardableResult
    static func openIfAppLink(_ url: URL, from viewController: UIViewController?) -> Bool {
        guard url.scheme?.lowercased() == "drel", url.host?.lowercased() == "app" else {
            return false
        }
        guard let link = DrelExternalAppLink.parse(url) else {
            presentAlert(title: "链接无效", message: "这个应用链接缺少 app_id，无法打开。", from: viewController)
            return true
        }
        open(link, from: viewController)
        return true
    }

    static func open(_ link: DrelExternalAppLink, from viewController: UIViewController?) {
        let registry = HTMLAppRuntimeCenter.shared.trustRegistry
        // Fail closed: only apps already trusted on this device open from an
        // external link; unregistered IDs get an explanation, not a browser.
        guard let manifest = registry.manifest(for: link.appID) else {
            presentAlert(
                title: "应用未注册",
                message: "“\(link.appID)”不在本机的受信应用列表中。请先在应用中心导入，或通过推送激活该应用。",
                from: viewController
            )
            return
        }

        let route = (link.route?.isEmpty == false ? link.route : nil) ?? manifest.routes.first ?? "/"
        do {
            let target = try HTMLAppLaunchResolver(trustRegistry: registry).resolve(
                appID: link.appID,
                route: route,
                parameters: link.parameters,
                source: .direct
            )
            // External launches always deliver via the bridge-free
            // containerOnlyURL (validated route + drel_param_* query items):
            // an external caller has no bridge context, and this keeps the
            // documented template contract identical across every train.
            let params = DrelMessageOpenPolicy.browserParams(
                for: target.containerOnlyURL,
                mode: .immersive,
                payload: nil,
                useManifestLoader: false,
                preferCachedContent: false
            )
            WebBrowserManager.shared.openBrowser(url: target.containerOnlyURL, params: params, from: viewController)
        } catch {
            presentAlert(title: "无法打开应用", message: error.localizedDescription, from: viewController)
        }
    }

    private static func presentAlert(title: String, message: String, from viewController: UIViewController?) {
        DispatchQueue.main.async {
            var presenter = viewController ?? UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                .first
            while let presented = presenter?.presentedViewController { presenter = presented }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            presenter?.present(alert, animated: true)
        }
    }
}
