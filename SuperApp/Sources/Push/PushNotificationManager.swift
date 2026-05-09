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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                if settings.authorizationStatus == .authorized {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                return
            }
        }
    }

    /// 处理 APNs Token 注册成功
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        print("[PushManager] Device token: \(token.prefix(8))...")

        registerTokenToBarkServer(token: token)
    }

    // MARK: - Bark Registration

    private func registerTokenToBarkServer(token: String) {
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
            ?? barkServerURL
            ?? "https://api.day.app"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key")
            ?? barkKey

        guard let key, !key.isEmpty else {
            print("[PushManager] Bark key not configured, skip token registration")
            return
        }

        guard var components = URLComponents(string: server) else {
            print("[PushManager] Invalid Bark server URL: \(server)")
            return
        }
        components.path = "/register"
        components.queryItems = [
            URLQueryItem(name: "devicetoken", value: token),
            URLQueryItem(name: "key", value: key)
        ]

        guard let url = components.url else {
            print("[PushManager] Failed to build Bark register URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                print("[PushManager] Bark register failed: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("[PushManager] Bark register success")
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[PushManager] Bark register failed with status: \(statusCode)")
            }
        }.resume()
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
