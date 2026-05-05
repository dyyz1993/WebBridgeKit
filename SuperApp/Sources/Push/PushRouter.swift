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

    private init() {}

    /// 处理推送通知点击
    /// - Parameters:
    ///   - userInfo: APNs payload
    ///   - rootViewController: 用于展示页面的根控制器
    func handle(userInfo: [AnyHashable: Any], from rootViewController: UIViewController?) {
        let payload = PushPayload(userInfo: userInfo)
        handle(payload: payload, from: rootViewController)
    }

    /// 处理解析后的 payload
    func handle(payload: PushPayload, from rootViewController: UIViewController?) {
        guard let rootVC = rootViewController else { return }

        // 1. 有 appid → 打开缓存的离线小程序
        if let appid = payload.appid {
            openCachedApp(appid: appid, params: payload.params, mode: payload.mode, from: rootVC)
            return
        }

        // 2. 有 url → 内置浏览器打开
        if let urlString = payload.url, let url = URL(string: urlString) {
            openBrowser(url: url, mode: payload.mode, from: rootVC)
            return
        }

        // 3. 都没有 → 不做路由，让 App 正常打开
        print("[PushRouter] No route target in payload")
    }

    // MARK: - Open Cached App

    private func openCachedApp(appid: String, params: [String: Any], mode: PushPayload.OpenMode, from rootVC: UIViewController) {
        print("[PushRouter] Opening cached app: \(appid)")

        if let result = ManifestStore.shared.getManifestByAppId(appid),
           let url = URL(string: result.key) {
            print("[PushRouter] Cache hit for appid: \(appid), url: \(url)")
            let browserParams = makeParams(for: url, mode: mode)
            WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: rootVC)
            return
        }

        print("[PushRouter] Cache miss for appid: \(appid), falling back to URL scheme")
        guard let url = URL(string: "app://\(appid)") else { return }
        let browserParams = makeParams(for: url, mode: mode)
        WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: rootVC)
    }

    // MARK: - Open Browser

    private func openBrowser(url: URL, mode: PushPayload.OpenMode, from rootVC: UIViewController) {
        print("[PushRouter] Opening URL: \(url) mode: \(mode)")
        let browserParams = makeParams(for: url, mode: mode)
        WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: rootVC)
    }

    // MARK: - Helper

    private func makeParams(for url: URL, mode: PushPayload.OpenMode) -> WebBrowserParams {
        switch mode {
        case .normal:
            return WebBrowserParams.from(url: url)
        case .immersive:
            return WebBrowserParams(
                displayMode: .immersive,
                hideNavigationBar: true,
                hideStatusBar: true,
                hideTabBar: true
            )
        case .modal:
            return WebBrowserParams(
                displayMode: .modal,
                modalSize: .percent(width: "85%", height: "70%")
            )
        }
    }
}
