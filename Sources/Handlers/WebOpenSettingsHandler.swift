//
//  WebOpenSettingsHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 打开系统设置处理器
public class WebOpenSettingsHandler: BaseWebNativeHandler {

    /// 处理打开设置请求
    /// - Parameters:
    ///   - body: 请求参数字典
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        runOnMainThread {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                self.reject(error: "Unable to open settings URL", completion: completion)
                return
            }

            var completed = false
            UIApplication.shared.open(settingsUrl) { success in
                guard !completed else { return }
                completed = true
                if success {
                    self.resolve(["opened": true], completion: completion)
                } else {
                    self.reject(error: "Failed to open settings", completion: completion)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard !completed else { return }
                completed = true
                self.resolve(["opened": true], completion: completion)
            }
        }
    }
}
