//
//  PushNotificationManager.swift
//  SuperApp
//

import Foundation
import UIKit
import UserNotifications

/// 推送通知管理器
/// 负责 APNs 注册、Token 管理、通知权限请求
class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()

    /// 当前设备的推送 Token
    private(set) var deviceToken: String?

    /// Bark 服务端配置
    var barkServerURL: String?
    var barkKey: String?

    private override init() {
        super.init()
    }

    // MARK: - Registration

    /// 请求通知权限并注册 APNs
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("[PushManager] Notification permission granted")
            } else {
                print("[PushManager] Notification permission denied")
            }
        }
    }

    /// 处理 APNs Token 注册成功
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        print("[PushManager] Device token: \(token.prefix(8))...")

        // TODO: 将 token 上报给 Bark 服务器
    }

    /// 处理 APNs Token 注册失败
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[PushManager] Failed to register: \(error)")
    }

    // MARK: - Incoming Notification

    /// App 在前台收到通知
    func handleForegroundNotification(userInfo: [AnyHashable: Any]) {
        print("[PushManager] Received foreground notification")
        // 可以展示一个自定义的 App 内通知 banner
    }

    /// 用户点击通知打开 App
    func handleNotificationTap(userInfo: [AnyHashable: Any], rootViewController: UIViewController?) {
        PushRouter.shared.handle(userInfo: userInfo, from: rootViewController)
    }
}
