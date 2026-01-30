//
//  WebNetworkHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import SystemConfiguration

// Framework imports

/// 网络状态处理器
/// 提供当前网络连通性和网络类型信息
public class WebNetworkHandler: BaseWebNativeHandler {

    /**
     * 处理获取网络状态请求
     * - Parameters:
     *   - body: 请求参数字典
     *   - completion: 结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let isReachable = checkNetworkReachability()
        let networkType = getNetworkType()

        resolve([
            "isConnected": isReachable,
            "networkType": networkType
        ], completion: completion)
    }

    /**
     * 检查网络是否可达
     * - Returns: 是否连通
     */
    private func checkNetworkReachability() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }

        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }

        let isReachable = flags.contains(.reachable)
        return isReachable
    }

    /**
     * 获取网络类型
     * - Returns: 网络类型字符串（wifi, cellular, none）
     */
    private func getNetworkType() -> String {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return "none"
        }

        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return "none"
        }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        if isReachable && !needsConnection {
            if !flags.contains(.isWWAN) {
                return "wifi"
            } else {
                return "cellular"
            }
        }

        return "none"
    }
}
