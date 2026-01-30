//
//  WebGetHistoryHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 获取导航历史的处理器
/// 通过 BarkBridge.callNative('getHistory', {}) 调用
public class WebGetHistoryHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let history = WebBrowserManager.shared.getNavigationHistory()

        let result = history.map { item in
            [
                "url": item.url.absoluteString,
                "title": item.title ?? "",
                "timestamp": item.timestamp.timeIntervalSince1970,
                "displayMode": item.displayMode.rawValue
            ]
        }

        resolve([
            "history": result,
            "count": result.count,
            "currentIndex": WebBrowserManager.shared.currentIndex
        ], completion: completion)
    }
}
