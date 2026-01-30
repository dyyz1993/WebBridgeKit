//
//  WebSystemInfoHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 系统信息处理器
public class WebSystemInfoHandler: BaseWebNativeHandler {

    /// 处理获取系统信息请求
    /// - Parameters:
    ///   - body: 请求参数字典
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        runOnMainThread {
            let info = self.getSystemInfo()
            self.resolve(info, completion: completion)
        }
    }

    private func getSystemInfo() -> [String: Any] {
        let device = UIDevice.current
        let screen = UIScreen.main

        return [
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            "appName": Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "",
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "deviceModel": device.model,
            "deviceName": device.name,
            "screenWidth": Int(screen.bounds.width),
            "screenHeight": Int(screen.bounds.height),
            "scale": screen.scale,
            "batteryLevel": Int(device.batteryLevel * 100),
            "batteryState": batteryStateString(device.batteryState),
            "preferredLanguage": Locale.preferredLanguages.first ?? "",
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier ?? ""
        ]
    }

    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging: return "charging"
        case .full: return "full"
        case .unplugged: return "unplugged"
        default: return "unknown"
        }
    }
}
