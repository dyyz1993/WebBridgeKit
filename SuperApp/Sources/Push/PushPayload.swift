//
//  PushPayload.swift
//  SuperApp
//

import Foundation

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
        self.appid = userInfo["appid"] as? String
        self.url = userInfo["url"] as? String
        self.title = userInfo["title"] as? String
        self.body = userInfo["body"] as? String
        self.sound = userInfo["sound"] as? String
        self.level = userInfo["level"] as? String
        self.group = userInfo["group"] as? String

        if let modeStr = userInfo["mode"] as? String {
            self.mode = OpenMode(rawValue: modeStr) ?? .normal
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
}
