//
//  WebClosePageHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 关闭当前页面的处理器
/// 通过 BarkBridge.callNative('closePage', { animated: true }) 调用
public class WebClosePageHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? [:]

        // 检查是否有活动浏览器
        guard WebBrowserManager.shared.getCurrentBrowser() != nil else {
            reject(error: "No active browser to close", code: 404, completion: completion)
            return
        }

        // 执行关闭
        let animated = params["animated"] as? Bool ?? true
        let reasonString = params["reason"] as? String ?? "userAction"
        let reason = WebBrowserParams.CloseReason.from(string: reasonString)

        runOnMainThread { [weak self] in
            WebBrowserManager.shared.closeBrowser(animated: animated, reason: reason)
            self?.resolve(["success": true, "reason": reasonString], completion: completion)
        }
    }
}
