//
//  PushPayload.swift
//  SuperApp
//

import Foundation
import WebBridgeKit

/// 解析推送通知的参数模型
struct PushPayload {

    /// 打开方式
    enum OpenMode: String {
        case normal          // 普通浏览器
        case immersive       // 沉浸式全屏
        case modal           // 浮窗弹在上面
    }

    /// 小程序 APP ID（对应缓存的离线应用）
    let appid: String?

    /// 受信任 HTML App 声明的内部路由
    let route: String?

    /// 协议版本
    let version: String

    /// 可选过期时间，防止旧通知重复导航
    let expiresAt: String?

    /// 可选通知唯一标识
    let nonce: String?

    /// 要打开的 URL
    let url: String?

    /// 打开模式
    let mode: OpenMode

    /// 传给网页的参数
    let params: [String: Any]

    /// 通知标题
    let title: String?

    /// 通知内容
    let body: String?

    /// 声音
    let sound: String?

    /// 中断级别
    let level: String?

    /// 分组 ID
    let group: String?

    init(userInfo: [AnyHashable: Any]) {
        self.appid = (userInfo["appId"] as? String) ?? (userInfo["appid"] as? String)
        self.route = userInfo["route"] as? String
        self.version = userInfo["version"] as? String ?? HTMLAppManifest.supportedSchemaVersion
        self.expiresAt = userInfo["expiresAt"] as? String
        self.nonce = userInfo["nonce"] as? String
        self.url = userInfo["url"] as? String
        let notification = userInfo["notification"] as? [String: Any]
        self.title = (notification?["title"] as? String) ?? (userInfo["title"] as? String)
        self.body = (notification?["body"] as? String) ?? (userInfo["body"] as? String)
        self.sound = userInfo["sound"] as? String
        self.level = userInfo["level"] as? String
        self.group = userInfo["group"] as? String

        if let modeStr = userInfo["mode"] as? String {
            self.mode = OpenMode(rawValue: modeStr) ?? .normal
        } else if let display = userInfo["display"] as? String {
            switch display {
            case "sheet", "inline": self.mode = .modal
            case "full": self.mode = .immersive
            default: self.mode = .normal
            }
        } else {
            self.mode = .normal
        }

        if let p = userInfo["params"] as? [String: Any] {
            self.params = p
        } else {
            self.params = [:]
        }
    }

    /// 是否有可路由的目标
    var hasRoute: Bool {
        return appid != nil || url != nil
    }

    var stringParams: [String: String] {
        params.reduce(into: [:]) { result, item in
            switch item.value {
            case let value as String:
                result[item.key] = value
            case let value as NSNumber:
                result[item.key] = value.stringValue
            default:
                break
            }
        }
    }

    var htmlAppEnvelope: HTMLAppPushEnvelope? {
        guard let appid, let route, let title, !title.isEmpty else { return nil }
        return HTMLAppPushEnvelope(
            version: version,
            appID: appid,
            route: route,
            parameters: stringParams,
            notification: HTMLAppPushNotification(title: title, body: body ?? ""),
            expiresAt: expiresAt,
            nonce: nonce
        )
    }
}
