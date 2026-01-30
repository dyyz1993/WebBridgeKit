//
//  WebShareHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 分享处理器
public class WebShareHandler: BaseWebNativeHandler {

    /// 处理分享请求
    /// - Parameters:
    ///   - body: 包含 text 和 url
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 兼容 body 或 body.params
        let params = body["params"] as? [String: Any] ?? body
        
        guard let text = params["text"] as? String,
              let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            reject(error: "Invalid parameters: text and url are required", completion: completion)
            return
        }

        // 在主线程执行分享
        runOnMainThread {
            let items: [Any] = [text, url]
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)

            if let topVC = self.topViewController {
                topVC.present(activityViewController, animated: true) {
                    self.resolve(completion: completion)
                }
            } else {
                self.reject(error: "No view controller", completion: completion)
            }
        }
    }
}
