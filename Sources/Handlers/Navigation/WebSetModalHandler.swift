//
//  WebSetModalHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 动态设置弹窗模式的处理器
/// 通过 BarkBridge.callNative('setModal', { width: '90%', height: '90%', mask: false }) 调用
public class WebSetModalHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? [:]

        // 检查当前是否是弹窗模式
        guard let currentModal = WebBrowserManager.shared.currentModal else {
            reject(error: "Current page is not a modal", code: 400, completion: completion)
            return
        }

        runOnMainThread { [weak self] in
            var updates: [String] = []

            // 更新宽度
            if let width = params["width"] as? String {
                currentModal.updateWidth(width)
                updates.append("width=\(width)")
            }

            // 更新高度
            if let height = params["height"] as? String {
                currentModal.updateHeight(height)
                updates.append("height=\(height)")
            }

            // 更新遮罩显示
            if let mask = params["mask"] as? Bool {
                currentModal.showMask = mask
                updates.append("mask=\(mask)")
            }

            self?.resolve([
                "success": true,
                "updates": updates
            ], completion: completion)
        }
    }
}
