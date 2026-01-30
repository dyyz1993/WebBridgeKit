//
//  WebClipboardHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 剪贴板功能处理器
public class WebClipboardHandler: BaseWebNativeHandler {

    /// 处理剪贴板请求
    /// - Parameters:
    ///   - body: 包含 type ("set" 或 "get") 和 data
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 从 params 中获取参数，兼容直接在 body 中传参的情况
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? "read"

        switch action {
        case "read":
            readClipboard(completion: completion)
        case "write":
            if let text = params["text"] as? String {
                writeClipboard(text: text, completion: completion)
            } else {
                reject(error: "Missing text parameter", completion: completion)
            }
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }

    private func readClipboard(completion: @escaping (Any) -> Void) {
        runOnMainThread {
            let text = UIPasteboard.general.string ?? ""
            self.resolve(["text": text], completion: completion)
        }
    }

    private func writeClipboard(text: String, completion: @escaping (Any) -> Void) {
        runOnMainThread {
            UIPasteboard.general.string = text
            self.resolve(["text": text], completion: completion)
        }
    }
}
