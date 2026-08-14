//
//  PushNotificationManager.swift
//  SuperApp
//

import Foundation
import UIKit
import UserNotifications
import WebBridgeKit

enum OfficialPushActivationResult {
    case ready
    case denied
    case failed(String)
}

/// 推送通知管理器
/// 负责 APNs 注册、Token 管理、通知权限请求
class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()

    /// 当前设备的推送 Token
    private(set) var deviceToken: String?

    /// Bark 服务端配置
    var barkServerURL: String?
    var barkKey: String?

    private struct PendingOfficialRegistration {
        let serverURL: String
        let key: String
        let completion: (OfficialPushActivationResult) -> Void
    }

    private var pendingOfficialRegistration: PendingOfficialRegistration?

    private override init() {
        super.init()
    }

    // MARK: - Registration

    func activateOfficialPush(
        serverURL: String,
        key: String,
        completion: @escaping (OfficialPushActivationResult) -> Void
    ) {
        barkServerURL = serverURL
        barkKey = key
        UserDefaults.standard.set(serverURL, forKey: "com.webbridgekit.bark.server")

        #if DEBUG
        if isOfficialPushUITest {
            activateOfficialPushForUITest(completion: completion)
            return
        }
        #endif

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    DispatchQueue.main.async {
                        if let error {
                            completion(.failed(error.localizedDescription))
                        } else if granted {
                            self.beginRemoteRegistration(serverURL: serverURL, key: key, completion: completion)
                        } else {
                            completion(.denied)
                        }
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    self.beginRemoteRegistration(serverURL: serverURL, key: key, completion: completion)
                }
            case .denied:
                DispatchQueue.main.async { completion(.denied) }
            @unknown default:
                DispatchQueue.main.async { completion(.failed(L10n.tr("official.push.error.permission"))) }
            }
        }
    }

    private func beginRemoteRegistration(
        serverURL: String,
        key: String,
        completion: @escaping (OfficialPushActivationResult) -> Void
    ) {
        pendingOfficialRegistration = PendingOfficialRegistration(
            serverURL: serverURL,
            key: key,
            completion: completion
        )
        if let deviceToken {
            registerTokenToBarkServer(token: deviceToken, serverURL: serverURL, key: key, completion: completion)
            pendingOfficialRegistration = nil
        } else {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 请求通知权限并注册 APNs
    /// - Parameter completion: 注册完成回调，success=true 代表注册成功
    func registerForPushNotifications(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // 尚未请求过权限 → 弹系统授权弹窗
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                            completion?(true)
                        } else {
                            #if DEBUG
                            print("[PushManager] User denied notification permission")
                            #endif
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
                    #if DEBUG
                    print("[PushManager] Push notification access denied")
                    #endif
                    completion?(false)
                }

            @unknown default:
                // .restricted 及其他未知状态
                DispatchQueue.main.async {
                    #if DEBUG
                    print("[PushManager] Push notification not available (restricted or unknown)")
                    #endif
                    completion?(false)
                }
            }
        }
    }

    /// 处理 APNs Token 注册成功
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        #if DEBUG
        print("[PushManager] Device token: \(token.prefix(8))...")
        #endif

        if let pending = pendingOfficialRegistration {
            pendingOfficialRegistration = nil
            registerTokenToBarkServer(
                token: token,
                serverURL: pending.serverURL,
                key: pending.key,
                completion: pending.completion
            )
        } else {
            registerTokenToBarkServer(token: token)
        }
    }

    // MARK: - Bark Registration

    private func registerTokenToBarkServer(
        token: String,
        serverURL: String? = nil,
        key explicitKey: String? = nil,
        completion: ((OfficialPushActivationResult) -> Void)? = nil
    ) {
        let server = serverURL
            ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
            ?? barkServerURL
            ?? "https://wbk.shanbox.19930810.xyz:8443"
        let key = explicitKey
            ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key")
            ?? barkKey

        guard let key, !key.isEmpty else {
            #if DEBUG
            print("[PushManager] Bark key not configured, skip token registration")
            #endif
            completion?(.failed(L10n.tr("official.push.error.identity")))
            return
        }

        guard let url = URL(string: server + "/register") else {
            #if DEBUG
            print("[PushManager] Invalid Bark server URL: \(server)")
            #endif
            completion?(.failed(L10n.tr("official.push.error.server")))
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
                #if DEBUG
                print("[PushManager] Bark register failed: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async { completion?(.failed(error.localizedDescription)) }
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                #if DEBUG
                print("[PushManager] Bark register success (POST)")
                #endif
                DispatchQueue.main.async { completion?(.ready) }
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                #if DEBUG
                print("[PushManager] Bark register failed with status: \(statusCode)")
                #endif
                DispatchQueue.main.async { completion?(.failed(L10n.tr("official.push.error.server"))) }
            }
        }.resume()
    }

    /// 处理 APNs Token 注册失败
    func didFailToRegisterForRemoteNotifications(error: Error) {
        #if DEBUG
        print("[PushManager] Failed to register: \(error)")
        #endif
        let completion = pendingOfficialRegistration?.completion
        pendingOfficialRegistration = nil
        completion?(.failed(error.localizedDescription))
    }

    #if DEBUG
    private var isOfficialPushUITest: Bool {
        return ProcessInfo.processInfo.isWebBridgeKitUITesting
            && ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_STATE"] != nil
    }

    private func activateOfficialPushForUITest(completion: @escaping (OfficialPushActivationResult) -> Void) {
        switch ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_STATE"] {
        case "denied": completion(.denied)
        case "error": completion(.failed(L10n.tr("official.push.error.server")))
        default: completion(.ready)
        }
    }
    #endif

    // MARK: - Incoming Notification

    /// App 在前台收到通知
    func handleForegroundNotification(userInfo: [AnyHashable: Any]) {
        #if DEBUG
        print("[PushManager] Received foreground notification")
        #endif
        // 可以展示一个自定义的 App 内通知 banner
    }

    /// 用户点击通知打开 App
    func handleNotificationTap(userInfo: [AnyHashable: Any], rootViewController: UIViewController?) {
        PushRouter.shared.handle(userInfo: userInfo, from: rootViewController)
    }
}
