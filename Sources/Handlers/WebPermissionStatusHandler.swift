//
//  WebPermissionStatusHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 权限状态查询处理器 - 返回所有权限状态
public class WebPermissionStatusHandler: BaseWebNativeHandler {

    /// 处理权限状态查询请求
    /// - Parameters:
    ///   - body: 请求参数字典
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        WebPermissionManager.shared.checkAllPermissions { allPermissions in
            self.runOnMainThread {
                // 计算统计信息
                let total = allPermissions.count
                let granted = allPermissions.filter { ($0["granted"] as? Bool) == true }.count
                let denied = allPermissions.filter { ($0["status"] as? String) == "denied" }.count
                let notDetermined = allPermissions.filter { ($0["status"] as? String) == "notDetermined" }.count

                self.resolve([
                    "permissions": allPermissions,
                    "summary": [
                        "total": total,
                        "granted": granted,
                        "denied": denied,
                        "notDetermined": notDetermined
                    ]
                ], completion: completion)
            }
        }
    }
}
