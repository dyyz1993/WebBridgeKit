#if DEBUG
import Foundation
import RealmSwift
import UIKit
import UserNotifications
import WebBridgeKit

enum TokenPushAction {
    case openTokenManager
    case openAPIKeyManager
    case openNotificationDebug
}

@MainActor
final class TokenPushHomeViewModel: ObservableObject {
    @Published var pushAuthorization = "Checking"
    @Published var deviceTokenState = "未注册"
    @Published var barkKeyState = "未配置"
    @Published var apiKeyCount = "0"
    @Published var accessTokenCount = "0"
    @Published var payloadText = TokenPushHomeViewModel.defaultPayload
    @Published var resultState: ResultPanel.State = .idle
    @Published var resultDetail = ""

    private var snapshotTask: Task<Void, Never>?

    var serviceItems: [AppShellStatusItem] {
        [
            AppShellStatusItem(title: "Bark", value: barkKeyState, tone: barkKeyState == "已配置" ? .success : .warning),
            AppShellStatusItem(title: "APNs", value: deviceTokenState, tone: deviceTokenState == "已注册" ? .success : .warning),
            AppShellStatusItem(title: "API", value: "Bark", tone: .success)
        ]
    }

    var redactedPushURL: String {
        let url = pushURL
        guard url.count > 42 else { return url }
        return "\(url.prefix(24))...\(url.suffix(12))"
    }

    var pushURL: String {
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
            ?? "https://wbk.shanbox.19930810.xyz:8443"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        return key.isEmpty ? server : "\(server)/\(key)"
    }

    func refreshSnapshot() {
        snapshotTask?.cancel()
        snapshotTask = Task { [weak self] in
            await Task.yield()
            self?.refreshSnapshotNow()
        }
    }

    private func refreshSnapshotNow() {
        let deviceToken = PushNotificationManager.shared.deviceToken
        deviceTokenState = deviceToken?.isEmpty == false ? "已注册" : "未注册"

        let barkKey = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        barkKeyState = barkKey.isEmpty ? "未配置" : "已配置"

        apiKeyCount = "\(APIKeyManager.shared.getAllKeys().count)"
        accessTokenCount = "\(AccessTokenManager.shared.getAllTokens().count)"

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.pushAuthorization = Self.authorizationTitle(settings.authorizationStatus)
            }
        }
    }

    func requestPushRegistration() {
        resultState = .loading("正在请求通知权限并注册 APNs")
        resultDetail = ""

        PushNotificationManager.shared.registerForPushNotifications { [weak self] success in
            Task { @MainActor in
                self?.refreshSnapshot()
                if success {
                    self?.resultState = .success("系统已接受推送注册请求")
                } else {
                    self?.resultState = .warning("通知权限未开启或注册未完成")
                }
                self?.resultDetail = """
                {
                  "authorization": "\(self?.pushAuthorization ?? "Unknown")",
                  "deviceToken": "\(self?.deviceTokenState ?? "未知")",
                  "barkKey": "\(self?.barkKeyState ?? "未知")"
                }
                """
            }
        }
    }

    func validatePayload() {
        guard let data = payloadText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            resultState = .failure("payload 不是合法 JSON Object")
            resultDetail = payloadText
            return
        }

        let payload = PushPayload(userInfo: object)
        resultState = payload.hasRoute ? .success("Bark payload 可以路由") : .warning("Bark payload 合法，但没有 appid 或 url")
        resultDetail = """
        {
          "barkCompatible": true,
          "title": "\(payload.title ?? "")",
          "body": "\(payload.body ?? "")",
          "mode": "\(payload.mode.rawValue)",
          "hasRoute": \(payload.hasRoute),
          "appid": "\(payload.appid ?? "")",
          "url": "\(payload.url ?? "")",
          "params": \(payload.params.count)
        }
        """
    }

    func copyPushURL() {
        UIPasteboard.general.string = pushURL
        resultState = .success("推送地址已复制")
        resultDetail = redactedPushURL
    }

    func copyPayloadResult() {
        UIPasteboard.general.string = resultDetail.isEmpty ? payloadText : resultDetail
    }

    private static func authorizationTitle(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "未询问"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "已授权"
        case .provisional:
            return "临时授权"
        case .ephemeral:
            return "临时会话"
        @unknown default:
            return "未知"
        }
    }

    private static let defaultPayload = """
    {
      "title": "WebBridgeKit",
      "body": "打开缓存页面",
      "url": "http://localhost:8081/test_resources/cache-demo.html",
      "mode": "normal",
      "group": "WebBridgeKit",
      "sound": "default",
      "level": "active",
      "params": {
        "source": "token-push"
      }
    }
    """
}

#endif
