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
    /// - Parameter completion: 注册完成回调，success=true 代表注册成功
    func registerForPushNotifications(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // 尚未请求过权限 → 弹系统授权弹窗
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                            completion?(true)
                        } else {
                            print("[PushManager] User denied notification permission")
                            completion?(false)
                        }
                    }
                }

            case .authorized, .provisional, .ephemeral:
                // 已有权限 → 直接注册 APNs
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    completion?(true)
                }

            case .denied:
                // 被拒绝 → 通知用户去设置里开启
                DispatchQueue.main.async {
                    print("[PushManager] Push notification access denied")
                    completion?(false)
                }

            @unknown default:
                // .restricted 及其他未知状态
                DispatchQueue.main.async {
                    print("[PushManager] Push notification not available (restricted or unknown)")
                    completion?(false)
                }
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
            ?? "https://wbk.shanbox.19930810.xyz:8443"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key")
            ?? barkKey

        guard let key, !key.isEmpty else {
            print("[PushManager] Bark key not configured, skip token registration")
            return
        }

        guard let url = URL(string: server + "/register") else {
            print("[PushManager] Invalid Bark server URL: \(server)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "deviceToken": token,
            "key": key
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                print("[PushManager] Bark register failed: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("[PushManager] Bark register success (POST)")
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
