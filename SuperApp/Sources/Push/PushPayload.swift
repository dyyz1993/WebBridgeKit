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

        self.mode = DrelMessageOpenPolicy.mode(
            rawValue: userInfo["mode"] as? String,
            display: userInfo["display"] as? String
        )

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

/// The one canonical presentation policy for a Drel message destination.
///
/// A notification can be opened immediately by `PushRouter`, or much later
/// from the inbox/detail screen after it has been persisted as a
/// `MessagePayload`.  Those paths must not reinterpret `mode` independently:
/// doing so previously made an immersive push reopen as a normal browser tab.
enum DrelMessageOpenPolicy {

    /// Accept the documented `mode` values plus the historical `display`
    /// aliases used by older senders. Unknown values deliberately fall back to
    /// a normal browser rather than granting a more disruptive presentation.
    static func mode(rawValue: String?, display: String? = nil) -> PushPayload.OpenMode {
        switch MessageTargetPresentation.resolve(mode: rawValue, display: display) {
        case .normal:
            return .normal
        case .immersive:
            return .immersive
        case .modal:
            return .modal
        }
    }

    static func mode(for payload: MessagePayload) -> PushPayload.OpenMode {
        mode(
            rawValue: payload.targetMode ?? payload.userInfo?["mode"],
            display: payload.userInfo?["display"]
        )
    }

    /// Registered HTML apps are app experiences, so they remain immersive by
    /// default. A modal message is the one explicit presentation override.
    static func registeredAppMode(for payload: MessagePayload) -> PushPayload.OpenMode {
        mode(for: payload) == .modal ? .modal : .immersive
    }

    static func browserParams(
        for url: URL,
        mode: PushPayload.OpenMode,
        payload: [String: String]? = nil,
        useManifestLoader: Bool = false,
        preferCachedContent: Bool = false
    ) -> WebBrowserParams {
        switch mode {
        case .normal:
            let parsed = WebBrowserParams.from(url: url)
            return WebBrowserParams(
                displayMode: parsed.displayMode,
                modalSize: parsed.modalSize,
                showMask: parsed.showMask,
                clickMaskCloses: parsed.clickMaskCloses,
                showCloseButton: parsed.showCloseButton,
                hideNavigationBar: parsed.hideNavigationBar,
                hideStatusBar: parsed.hideStatusBar,
                hideTabBar: parsed.hideTabBar,
                disableSwipeBack: parsed.disableSwipeBack,
                orientation: parsed.orientation,
                allowJavaScriptClose: parsed.allowJavaScriptClose,
                customTitle: parsed.customTitle,
                debugMode: parsed.debugMode,
                payload: payload,
                useManifestLoader: useManifestLoader,
                preferCachedContent: preferCachedContent
            )
        case .immersive:
            return WebBrowserParams(
                displayMode: .immersive,
                hideNavigationBar: true,
                hideStatusBar: true,
                hideTabBar: true,
                payload: payload,
                useManifestLoader: useManifestLoader,
                preferCachedContent: preferCachedContent
            )
        case .modal:
            return WebBrowserParams(
                displayMode: .modal,
                modalSize: .percent(width: "85%", height: "70%"),
                payload: payload,
                useManifestLoader: useManifestLoader,
                preferCachedContent: preferCachedContent
            )
        }
    }
}
