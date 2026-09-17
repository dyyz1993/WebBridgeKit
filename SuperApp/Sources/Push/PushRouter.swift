//
//  PushRouter.swift
//  SuperApp
//

import Foundation
import UIKit
import WebBridgeKit

/// 推送通知点击后的路由处理器
/// 负责根据推送参数决定打开什么页面、用什么模式
class PushRouter {

    static let shared = PushRouter()

    private let launchResolver: HTMLAppLaunchResolver

    private init() {
        launchResolver = HTMLAppLaunchResolver(
            trustRegistry: HTMLAppRuntimeCenter.shared.trustRegistry
        )
    }

    /// 处理推送通知点击
    /// - Parameters:
    ///   - userInfo: APNs payload
    ///   - rootViewController: 用于展示页面的根控制器
    func handle(userInfo: [AnyHashable: Any], from rootViewController: UIViewController?) {
        let payload = PushPayload(userInfo: userInfo)

        // 无显式路由（route/appid/url 都没有）的横幅点击应落到收件箱里
        // 对应的那条消息，而不是停留在上次离开的页面。
        if payload.route == nil && payload.appid == nil && payload.url == nil {
            openInboxMessage(userInfo: userInfo, from: rootViewController)
            return
        }

        handle(payload: payload, from: rootViewController)
    }

    /// 切换到通知页并请求收件箱定位、打开对应消息。
    private func openInboxMessage(userInfo: [AnyHashable: Any], from rootViewController: UIViewController?) {
        guard let tabBarController = rootViewController as? UITabBarController,
              let viewControllers = tabBarController.viewControllers,
              let inboxIndex = viewControllers.firstIndex(where: { controller in
                  (controller as? UINavigationController)?.viewControllers.first is InboxViewController
                      || controller is InboxViewController
              })
        else { return }

        var focusInfo: [String: String] = [:]
        if let title = userInfo["title"] as? String { focusInfo["title"] = title }
        if let body = userInfo["body"] as? String { focusInfo["body"] = body }

        // 冷启动时收件箱尚未绑定订阅，先暂存待办再切页；收件箱就绪后消费。
        if let title = focusInfo["title"], let body = focusInfo["body"] {
            InboxViewController.pendingFocus = (title, body)
        }
        tabBarController.selectedIndex = inboxIndex

        // 热启动：收件箱已可见，直接通知定位
        NotificationCenter.default.post(name: .focusInboxMessage, object: nil, userInfo: focusInfo)
    }

    /// 处理解析后的 payload
    func handle(payload: PushPayload, from rootViewController: UIViewController?) {
        guard let rootVC = rootViewController else { return }

        // 1. 新协议必须经过已注册清单和路由白名单校验。
        if payload.route != nil {
            openTrustedHTMLApp(payload: payload, from: rootVC)
            return
        }

        // 2. 旧协议仅保留兼容，不具备精确内部路由能力。
        if let appid = payload.appid {
            openCachedApp(appid: appid, params: payload.params, mode: payload.mode, from: rootVC)
            return
        }

        // 3. 有 url → 内置浏览器打开
        if let urlString = payload.url, let url = URL(string: urlString) {
            openBrowser(url: url, mode: payload.mode, from: rootVC)
            return
        }

        // 3. 都没有 → 不做路由，让 App 正常打开
        #if !DREL_CONTAINER_ONLY
        print("[PushRouter] No route target in payload")
        #endif
    }

    // MARK: - Open Cached App

    private func openTrustedHTMLApp(payload: PushPayload, from rootVC: UIViewController) {
        guard let envelope = payload.htmlAppEnvelope else {
            StructuredLogger.shared.warning(
                "[PushRouter] Rejected incomplete HTML app notification",
                category: .navigation
            )
            return
        }

        DrelPushAppCatalogCoordinator.shared.activateIfTrusted(
            appID: envelope.appID,
            route: envelope.route
        ) { [weak self, weak rootVC] accepted in
            guard accepted, let self, let rootVC else {
                StructuredLogger.shared.warning(
                    "[PushRouter] Rejected HTML app route because no signed manifest accepted it",
                    category: .navigation
                )
                return
            }
            self.openResolvedTrustedHTMLApp(envelope: envelope, payload: payload, from: rootVC)
        }
    }

    private func openResolvedTrustedHTMLApp(
        envelope: HTMLAppPushEnvelope,
        payload: PushPayload,
        from rootVC: UIViewController
    ) {
        do {
            let target = try launchResolver.resolve(envelope: envelope)

            if !DrelContainerBuildPolicy.nativeBridgeEnabled {
                // Store builds deliberately provide no native JS bridge. The
                // validated route and parameters travel in namespaced URL
                // query items instead, so the PWA can render its destination
                // using ordinary web APIs while strong-offline packages still
                // open their signed local entrypoint.
                let browserParams = DrelMessageOpenPolicy.browserParams(
                    for: target.containerOnlyURL,
                    mode: payload.mode == .modal ? .modal : .immersive,
                    payload: nil,
                    useManifestLoader: false,
                    preferCachedContent: false
                )
                WebBrowserManager.shared.openBrowser(
                    url: target.containerOnlyURL,
                    params: browserParams,
                    from: rootVC
                )
                return
            }

            var bridgePayload = target.context.bridgePayload
            bridgePayload["webbridgekitOfflineMode"] = target.offlineMode.rawValue
            bridgePayload["webbridgekitPageURL"] = target.pageURL.absoluteString
            let browserParams = DrelMessageOpenPolicy.browserParams(
                for: target.loaderURL,
                // Registered PWAs are app experiences, not browser tabs. They
                // default to immersive mode; modal is the sole explicit override.
                mode: payload.mode == .modal ? .modal : .immersive,
                payload: bridgePayload,
                useManifestLoader: false,
                preferCachedContent: target.offlineMode == .partial
            )
            WebBrowserManager.shared.openBrowser(
                url: target.loaderURL,
                params: browserParams,
                from: rootVC
            )
        } catch {
            StructuredLogger.shared.warning(
                "[PushRouter] Rejected HTML app route: \(error.localizedDescription)",
                category: .navigation
            )
        }
    }

    private func openCachedApp(appid: String, params: [String: Any], mode: PushPayload.OpenMode, from rootVC: UIViewController) {
        #if !DREL_CONTAINER_ONLY
        print("[PushRouter] Opening cached app: \(appid)")
        #endif

        if let result = ManifestStore.shared.getManifestByAppId(appid),
           let url = URL(string: result.key) {
            #if !DREL_CONTAINER_ONLY
            print("[PushRouter] Cache hit for appid: \(appid), url: \(url)")
            #endif
            let browserParams = DrelMessageOpenPolicy.browserParams(
                for: url,
                mode: mode,
                payload: stringParams(params),
                useManifestLoader: true
            )
            WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: rootVC)
            return
        }

        #if !DREL_CONTAINER_ONLY
        print("[PushRouter] Cache miss for appid: \(appid), falling back to URL scheme")
        #endif
        guard let url = URL(string: "app://\(appid)") else { return }
        let browserParams = DrelMessageOpenPolicy.browserParams(
            for: url,
            mode: mode,
            payload: stringParams(params),
            useManifestLoader: true
        )
        WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: rootVC)
    }

    // MARK: - Open Browser

    private func openBrowser(url: URL, mode: PushPayload.OpenMode, from rootVC: UIViewController) {
        #if !DREL_CONTAINER_ONLY
        print("[PushRouter] Opening URL: \(url) mode: \(mode)")
        #endif
        // A plain push `url` is an ordinary HTTPS destination, not an
        // installed HTML-app package. Sending it through the manifest loader
        // makes normal websites fail with a manifest-related toast.
        let browserParams = DrelMessageOpenPolicy.browserParams(
            for: url,
            mode: mode,
            useManifestLoader: false,
            preferCachedContent: false
        )
        WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: rootVC)
    }

    private func stringParams(_ params: [String: Any]) -> [String: String] {
        params.reduce(into: [:]) { result, item in
            if let value = item.value as? String {
                result[item.key] = value
            } else if let value = item.value as? NSNumber {
                result[item.key] = value.stringValue
            }
        }
    }
}
