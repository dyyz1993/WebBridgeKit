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
        // TODO: 对接 ManifestCacheManager，通过 appid 查找缓存
        // 如果有缓存 → 离线秒开
        // 如果没有 → 降级为在线加载，并触发后台缓存
        
        print("[PushRouter] Opening cached app: \(appid)")
        
        // 降级方案：暂时用 URL 方式打开
        // 后续对接 ManifestCacheManager.shared 后替换
        let params = WebBrowserParams(url: "app://\(appid)")
        applyMode(params, mode: mode)
        WebBrowserManager.shared.open(params: params, from: rootVC)
    }
    
    // MARK: - Open Browser
    
    private func openBrowser(url: URL, mode: PushPayload.OpenMode, from rootVC: UIViewController) {
        print("[PushRouter] Opening URL: \(url) mode: \(mode)")
        
        let params = WebBrowserParams(url: url.absoluteString)
        applyMode(params, mode: mode)
        WebBrowserManager.shared.open(params: params, from: rootVC)
    }
    
    // MARK: - Helper
    
    private func applyMode(_ params: WebBrowserParams, mode: PushPayload.OpenMode) {
        switch mode {
        case .normal:
            break  // 默认就是普通模式
        case .immersive:
            params.hideNavigationBar = true
            params.hideStatusBar = true
            params.hideTabBar = true
        case .modal:
            params.displayMode = .modal  // 如果 WebBrowserParams 支持 modal
            params.modalWidth = 0.85
            params.modalHeight = 0.7
        }
    }
}
