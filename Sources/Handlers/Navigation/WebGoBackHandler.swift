//
//  WebGoBackHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 后退的处理器
/// 通过 BarkBridge.callNative('goBack', { steps: 1 }) 调用
public class WebGoBackHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? [:]
        let steps = params["steps"] as? Int ?? 1

        let success = WebBrowserManager.shared.goBack(steps: steps)

        if success {
            resolve([
                "success": true,
                "steps": steps,
                "currentIndex": WebBrowserManager.shared.currentIndex
            ], completion: completion)
        } else {
            resolve([
                "success": false,
                "message": "Cannot go back - already at the beginning",
                "steps": 0,
                "currentIndex": WebBrowserManager.shared.currentIndex
            ], completion: completion)
        }
    }
}
