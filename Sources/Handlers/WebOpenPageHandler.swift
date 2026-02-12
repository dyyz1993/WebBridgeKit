//
//  WebOpenPageHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 处理页面打开请求的处理器
/// 支持打开本地页面、远程URL，以及多种显示模式
///
/// 调用方式：
/// - BarkBridge.callNative('openPage', { page: 'sdk_test' })
/// - BarkBridge.callNative('openPage', { page: 'sdk_test', mode: 'immersive' })
/// - BarkBridge.callNative('openPage', { page: 'menu', mode: 'modal', width: '50%' })
/// - BarkBridge.callNative('openPage', { url: 'https://example.com' })
public class WebOpenPageHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? [:]

        // 构建 URL
        var components = URLComponents(string: "webbridgekit://internal")
        var queryItems: [URLQueryItem] = []

        // 添加页面或URL参数
        if let pageName = params["page"] as? String {
            // 验证页面名称，防止路径遍历攻击
            do {
                try InputValidator.validateHTMLName(pageName)
                queryItems.append(URLQueryItem(name: "page", value: pageName))
            } catch {
                reject(error: "Invalid page name: \(error.localizedDescription)", completion: completion)
                return
            }
        } else if let urlString = params["url"] as? String {
            // 远程 URL
            if let url = URL(string: urlString) {
                openRemoteURL(url, params: params, completion: completion)
                return
            }
        } else {
            reject(error: "Missing parameter: page or url", completion: completion)
            return
        }

        // 添加其他参数到 URL query
        var modeValue: String?
        if let mode = params["mode"] as? String {
            modeValue = mode
        }
        // 处理 immersive 参数（转换为 mode）
        if let immersive = params["immersive"] as? Bool, immersive {
            // 只有当 mode 未设置时才使用 immersive
            if modeValue == nil {
                modeValue = "immersive"
            }
        }
        if let mode = modeValue {
            queryItems.append(URLQueryItem(name: "mode", value: mode))
        }
        if let modal = params["modal"] as? String {
            queryItems.append(URLQueryItem(name: "modal", value: modal))
        }
        if let width = params["width"] as? String {
            queryItems.append(URLQueryItem(name: "width", value: width))
        }
        if let height = params["height"] as? String {
            queryItems.append(URLQueryItem(name: "height", value: height))
        }
        if let mask = params["mask"] as? Bool {
            queryItems.append(URLQueryItem(name: "mask", value: mask ? "1" : "0"))
        }
        if let clickMaskClose = params["clickMaskClose"] as? Bool {
            queryItems.append(URLQueryItem(name: "clickMaskClose", value: clickMaskClose ? "1" : "0"))
        }
        if let hideStatusBar = params["hideStatusBar"] as? Bool {
            queryItems.append(URLQueryItem(name: "hideStatusBar", value: hideStatusBar ? "1" : "0"))
        }
        // 🔥 新增参数
        if let hideTabBar = params["hideTabBar"] as? Bool {
            queryItems.append(URLQueryItem(name: "hideTabBar", value: hideTabBar ? "1" : "0"))
        }
        if let disableSwipeBack = params["disableSwipeBack"] as? Bool {
            queryItems.append(URLQueryItem(name: "disableSwipeBack", value: disableSwipeBack ? "1" : "0"))
        }
        if let title = params["title"] as? String {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        if let orientation = params["orientation"] as? String {
            queryItems.append(URLQueryItem(name: "orientation", value: orientation))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            reject(error: "Failed to construct URL", completion: completion)
            return
        }

        WebBridgeLogger.shared.log(.info, "🚀 [OpenPage] Opening page with params: \(params)")

        runOnMainThread { [weak self] in
            WebBrowserManager.shared.openBrowser(url: url, params: WebBrowserParams.from(url: url), from: self?.topViewController)
            self?.resolve(["status": "opening", "params": params], completion: completion)
        }
    }

    // MARK: - Private Methods

    private func openRemoteURL(_ url: URL, params: [String: Any], completion: @escaping (Any) -> Void) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []

        // 添加参数到 query string
        if let mode = params["mode"] as? String {
            queryItems.append(URLQueryItem(name: "mode", value: mode))
        }
        // ... 其他参数

        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            reject(error: "Failed to construct URL", completion: completion)
            return
        }

        runOnMainThread { [weak self] in
            WebBrowserManager.shared.openBrowser(url: finalURL, params: WebBrowserParams.from(url: finalURL), from: self?.topViewController)
            self?.resolve(["status": "opening", "url": finalURL.absoluteString], completion: completion)
        }
    }
}
