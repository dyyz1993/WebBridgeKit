//
//  PushNotificationManager.swift
//  SuperApp
//

import Foundation
import Security
import UIKit
import UserNotifications
import WebBridgeKit

enum OfficialPushActivationResult {
  case ready
  case denied
  case failed(String)
}

enum SelfHostedPushActivationResult {
  case ready(SelfHostedPushConfiguration)
  case denied
  case failed(String)
}

enum OfficialPushRevocationError: LocalizedError {
  case deviceTokenUnavailable
  case invalidServerURL
  case requestFailed(String)

  var errorDescription: String? {
    switch self {
    case .deviceTokenUnavailable:
      return "当前设备尚未完成推送注册，请稍后重试。"
    case .invalidServerURL:
      return L10n.tr("official.push.error.server")
    case .requestFailed(let message):
      return message
    }
  }
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

  private struct PendingSelfHostedRegistration {
    let configuration: SelfHostedPushConfiguration
    let pairingToken: String
    let publicKey: String
    let completion: (SelfHostedPushActivationResult) -> Void
  }
  private var pendingSelfHostedRegistration: PendingSelfHostedRegistration?

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
    // The official identity is intentionally public in the copyable endpoint.
    // Persisting it here lets a future APNs token rotation re-register the
    // official channel even when a self-hosted channel is also configured.
    UserDefaults.standard.set(key, forKey: "com.webbridgekit.bark.key")

    #if !DREL_CONTAINER_ONLY
      if isOfficialPushUITest {
        activateOfficialPushForUITest(completion: completion)
        return
      }
    #endif

    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      guard let self else { return }
      switch settings.authorizationStatus {
      case .notDetermined:
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
          granted, error in
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

  /// Imports a deployment QR URL or a pasted HTTPS server address, obtains a
  /// one-time pairing ticket when needed, and registers this installation's
  /// X25519 public key. The private key is never sent to the server.
  func activateSelfHostedPush(
    importPayload: String,
    completion: @escaping (SelfHostedPushActivationResult) -> Void
  ) {
    let parsed: SelfHostedPushConfiguration.Import
    do { parsed = try SelfHostedPushConfiguration.parseImport(importPayload) } catch {
      completion(.failed(error.localizedDescription))
      return
    }

    fetchSelfHostedDescriptor(serverURL: parsed.serverURL, relayKind: parsed.relayKind) { [weak self] result in
      switch result {
      case .failure(let error): completion(.failed(error.localizedDescription))
      case .success(let descriptor):
        guard descriptor.schema == parsed.relayKind.descriptorSchema,
          let baseURL = URL(string: descriptor.publicBaseURL),
          Self.sameOrigin(parsed.serverURL, baseURL)
        else {
          completion(
            .failed(SelfHostedPushConfiguration.ImportError.invalidDescriptor.localizedDescription))
          return
        }
        do {
          try SelfHostedPushConfiguration.validate(baseURL)
          let registrationPath = try SelfHostedPushConfiguration.validatedEndpointPath(
            descriptor.registrationPath)
          let pairingPath = try SelfHostedPushConfiguration.validatedEndpointPath(
            descriptor.pairingPath)
          let healthPath = try SelfHostedPushConfiguration.validatedEndpointPath(
            descriptor.healthPath)
          let unregisterPath = try descriptor.unregisterPath.map {
            try SelfHostedPushConfiguration.validatedEndpointPath($0)
          }
          let recipientPath = try descriptor.recipientPath.map {
            try SelfHostedPushConfiguration.validatedEndpointPath($0)
          }
          let deliveryPath = try descriptor.deliveryPath.map {
            try SelfHostedPushConfiguration.validatedEndpointPath($0)
          }
          if parsed.relayKind == .managedEncrypted {
            guard recipientPath?.contains("{deviceKey}") == true,
              deliveryPath?.contains("{deviceKey}") == true,
              descriptor.envelopeSchema == SelfHostedPushCrypto.schema
            else { throw SelfHostedPushConfiguration.ImportError.invalidDescriptor }
          }
          guard let self else { return }
          self.validateSelfHostedHealth(
            serverURL: descriptor.publicBaseURL,
            healthPath: healthPath
          ) { healthResult in
            switch healthResult {
            case .failure(let error): completion(.failed(error.localizedDescription))
            case .success:
              do {
                let existingConfiguration = SelfHostedPushConfiguration.load()
                let isServerChange =
                  existingConfiguration?.serverURL
                  .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                  != descriptor.publicBaseURL.trimmingCharacters(
                    in: CharacterSet(charactersIn: "/"))
                  || existingConfiguration?.resolvedRelayKind != parsed.relayKind
                let identity =
                  try isServerChange
                  ? SelfHostedPushCrypto.rotateIdentity()
                  : SelfHostedPushCrypto.currentOrCreateIdentity()
                let configuration = SelfHostedPushConfiguration(
                  name: descriptor.name,
                  serverURL: descriptor.publicBaseURL.trimmingCharacters(
                    in: CharacterSet(charactersIn: "/")),
                  registrationPath: registrationPath,
                  pairingPath: pairingPath,
                  deviceKey: isServerChange
                    ? Self.randomSelfHostedDeviceKey()
                    : (existingConfiguration?.deviceKey ?? Self.randomSelfHostedDeviceKey()),
                  relayKind: parsed.relayKind,
                  unregisterPath: unregisterPath,
                  recipientPath: recipientPath,
                  deliveryPath: deliveryPath,
                  envelopeSchema: descriptor.envelopeSchema
                )
                self.obtainPairingToken(
                  existing: parsed.pairingToken,
                  configuration: configuration,
                  publicKey: identity.publicKey,
                  completion: completion
                )
              } catch { completion(.failed(error.localizedDescription)) }
            }
          }
        } catch { completion(.failed(error.localizedDescription)) }
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
      registerTokenToBarkServer(
        token: deviceToken, serverURL: serverURL, key: key, completion: completion)
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
          granted, _ in
          DispatchQueue.main.async {
            if granted {
              UIApplication.shared.registerForRemoteNotifications()
              completion?(true)
            } else {
              #if !DREL_CONTAINER_ONLY
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
          #if !DREL_CONTAINER_ONLY
            print("[PushManager] Push notification access denied")
          #endif
          completion?(false)
        }

      @unknown default:
        // .restricted 及其他未知状态
        DispatchQueue.main.async {
          #if !DREL_CONTAINER_ONLY
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
    #if !DREL_CONTAINER_ONLY
      print("[PushManager] Device token: \(token)")
    #endif

    if let pending = pendingOfficialRegistration {
      pendingOfficialRegistration = nil
      registerTokenToBarkServer(
        token: token,
        serverURL: pending.serverURL,
        key: pending.key,
        completion: pending.completion
      )
      refreshSelfHostedRegistrationIfNeeded()
    } else if let pending = pendingSelfHostedRegistration {
      pendingSelfHostedRegistration = nil
      registerSelfHostedToken(token: token, pending: pending)
      registerTokenToBarkServer(token: token)
    } else if let configuration = SelfHostedPushConfiguration.load() {
      // Bark keeps all saved server registrations alive. Drel mirrors that:
      // a rotated token refreshes the self-hosted route *and* the independent
      // official route rather than treating them as mutually exclusive.
      activateSelfHostedPush(importPayload: configuration.reconnectImportPayload()) { _ in }
      registerTokenToBarkServer(token: token)
    } else {
      registerTokenToBarkServer(token: token)
    }
  }

  private func refreshSelfHostedRegistrationIfNeeded() {
    guard let configuration = SelfHostedPushConfiguration.load() else { return }
    activateSelfHostedPush(importPayload: configuration.reconnectImportPayload()) { _ in }
  }

  private func fetchSelfHostedDescriptor(
    serverURL: URL,
    relayKind: DrelPushRelayKind,
    completion: @escaping (Result<SelfHostedPushDescriptor, Error>) -> Void
  ) {
    let base = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard let url = URL(string: base + relayKind.descriptorPath) else {
      completion(.failure(SelfHostedPushConfiguration.ImportError.invalidAddress))
      return
    }
    URLSession.shared.dataTask(with: url) { data, response, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard let data, let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode),
        let descriptor = try? JSONDecoder().decode(SelfHostedPushDescriptor.self, from: data)
      else {
        completion(.failure(SelfHostedPushConfiguration.ImportError.invalidDescriptor))
        return
      }
      completion(.success(descriptor))
    }.resume()
  }

  private func validateSelfHostedHealth(
    serverURL: String,
    healthPath: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard
      let url = try? SelfHostedPushConfiguration.endpointURL(serverURL: serverURL, path: healthPath)
    else {
      completion(.failure(SelfHostedPushConfiguration.ImportError.invalidDescriptor))
      return
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard let data, let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode),
        let health = try? JSONDecoder().decode(SelfHostedPushHealthResponse.self, from: data),
        health.status == "ok", health.apnsReady != false
      else {
        completion(.failure(SelfHostedPushConfiguration.ImportError.invalidDescriptor))
        return
      }
      completion(.success(()))
    }.resume()
  }

  private func obtainPairingToken(
    existing: String?, configuration: SelfHostedPushConfiguration, publicKey: String,
    completion: @escaping (SelfHostedPushActivationResult) -> Void
  ) {
    if let existing {
      beginSelfHostedRegistration(
        configuration: configuration, pairingToken: existing, publicKey: publicKey,
        completion: completion)
      return
    }
    guard
      let url = try? SelfHostedPushConfiguration.endpointURL(
        serverURL: configuration.serverURL,
        path: configuration.pairingPath
      )
    else {
      completion(
        .failed(SelfHostedPushConfiguration.ImportError.invalidAddress.localizedDescription))
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard error == nil, let data, let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode),
        let pairing = try? JSONDecoder().decode(SelfHostedPairingResponse.self, from: data)
      else {
        completion(.failed("无法向推送服务获取配对许可。"))
        return
      }
      self?.beginSelfHostedRegistration(
        configuration: configuration, pairingToken: pairing.pairingToken, publicKey: publicKey,
        completion: completion)
    }.resume()
  }

  private func beginSelfHostedRegistration(
    configuration: SelfHostedPushConfiguration, pairingToken: String, publicKey: String,
    completion: @escaping (SelfHostedPushActivationResult) -> Void
  ) {
    pendingSelfHostedRegistration = .init(
      configuration: configuration, pairingToken: pairingToken, publicKey: publicKey,
      completion: completion)
    if let deviceToken = deviceToken ?? Self.uiTestingSelfHostedDeviceToken {
      let pending = pendingSelfHostedRegistration!
      pendingSelfHostedRegistration = nil
      registerSelfHostedToken(token: deviceToken, pending: pending)
      return
    }
    registerForPushNotifications { [weak self] granted in
      if !granted {
        self?.pendingSelfHostedRegistration = nil
        completion(.denied)
      }
    }
  }

  private func registerSelfHostedToken(token: String, pending: PendingSelfHostedRegistration) {
    guard
      let url = try? SelfHostedPushConfiguration.endpointURL(
        serverURL: pending.configuration.serverURL,
        path: pending.configuration.registrationPath
      )
    else {
      pending.completion(
        .failed(SelfHostedPushConfiguration.ImportError.invalidAddress.localizedDescription))
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "deviceToken": token, "deviceKey": pending.configuration.deviceKey,
      "encryptionPublicKey": pending.publicKey, "pairingToken": pending.pairingToken,
      "platform": "ios",
      "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "",
    ])
    URLSession.shared.dataTask(with: request) { data, response, error in
      guard error == nil, let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode)
      else {
        pending.completion(
          .failed(Self.selfHostedRegistrationFailureMessage(
            statusCode: (response as? HTTPURLResponse)?.statusCode, responseData: data)))
        return
      }
      pending.configuration.save()
      pending.completion(.ready(pending.configuration))
    }.resume()
  }

  /// Registration is where a one-time pairing ticket is consumed. Surface a
  /// recoverable expired/redeemed-ticket result instead of implying that the
  /// device itself failed to register.
  static func selfHostedRegistrationFailureMessage(
    statusCode: Int?, responseData: Data?
  ) -> String {
    switch statusCode {
    case 401:
      return "二维码已失效或已被使用，请重新获取并立即扫描。"
    case 400:
      return "推送配置无效，请重新扫描配置码后再试。"
    case 429:
      return "配对请求过于频繁，请稍后重新获取二维码。"
    case 503:
      return "推送服务暂时不可用，请稍后重试。"
    default:
      // Keep server response bodies out of the UI: they may be gateway
      // implementation details and do not help the user recover safely.
      _ = responseData
      return "推送服务未能登记此设备，请检查网络后重试。"
    }
  }

  private static func randomSelfHostedDeviceKey() -> String {
    // 18 random bytes encode to a 24-character base64url capability. This
    // satisfies the managed service's minimum length without weakening the
    // existing direct self-hosted path.
    var bytes = [UInt8](repeating: 0, count: 18)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }

  /// UI automation cannot obtain a real APNs token from the Simulator. Keep a
  /// deterministic placeholder strictly in Debug UI-test processes so the
  /// pairing/register protocol can be exercised end-to-end against an
  /// isolated local service. Production builds always require the APNs token
  /// supplied by UIApplicationDelegate.
  private static var uiTestingSelfHostedDeviceToken: String? {
    #if DEBUG
      guard ProcessInfo.processInfo.isWebBridgeKitUITesting else { return nil }
      let token = ProcessInfo.processInfo.environment["WBK_SELF_HOSTED_UI_TEST_DEVICE_TOKEN"]
      return token?.isEmpty == false ? token : nil
    #else
      return nil
    #endif
  }

  private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
    lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
      && lhs.host?.lowercased() == rhs.host?.lowercased()
      && lhs.port == rhs.port
  }

  // MARK: - Bark Registration

  private func registerTokenToBarkServer(
    token: String,
    serverURL: String? = nil,
    key explicitKey: String? = nil,
    completion: ((OfficialPushActivationResult) -> Void)? = nil
  ) {
    #if DREL_CONTAINER_ONLY
      // Store Drel has one immutable official origin. A custom relay is
      // registered through SelfHostedPushConfiguration and must never be
      // smuggled into this legacy official-registration fallback.
      let server = HTMLAppGatewayDefaults.official.baseURL
    #else
      let server =
        serverURL
        ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
        ?? barkServerURL
        ?? HTMLAppGatewayDefaults.official.baseURL
    #endif
    let key =
      explicitKey
      ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key")
      ?? barkKey

    guard let key, !key.isEmpty else {
      #if !DREL_CONTAINER_ONLY
        print("[PushManager] Bark key not configured, skip token registration")
      #endif
      completion?(.failed(L10n.tr("official.push.error.identity")))
      return
    }

    guard let url = URL(string: server + "/register") else {
      #if !DREL_CONTAINER_ONLY
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
      "key": key,
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { _, response, error in
      if let error {
        #if !DREL_CONTAINER_ONLY
          print("[PushManager] Bark register failed: \(error.localizedDescription)")
        #endif
        DispatchQueue.main.async { completion?(.failed(error.localizedDescription)) }
        return
      }
      if let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
      {
        #if !DREL_CONTAINER_ONLY
          print("[PushManager] Bark register success (POST)")
        #endif
        DispatchQueue.main.async { completion?(.ready) }
      } else {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        #if !DREL_CONTAINER_ONLY
          print("[PushManager] Bark register failed with status: \(statusCode)")
        #endif
        DispatchQueue.main.async { completion?(.failed(L10n.tr("official.push.error.server"))) }
      }
    }.resume()
  }

  /// Revokes exactly one public push identity for this APNs token. Address
  /// rotation must complete this request before replacing local state, or
  /// the old public URL would keep delivering indefinitely.
  func revokeOfficialPush(
    serverURL: String,
    key: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let deviceToken, !deviceToken.isEmpty else {
      completion(.failure(OfficialPushRevocationError.deviceTokenUnavailable))
      return
    }
    let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard let url = URL(string: base + "/unregister") else {
      completion(.failure(OfficialPushRevocationError.invalidServerURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 15
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "deviceToken": deviceToken,
      "key": key,
    ])

    URLSession.shared.dataTask(with: request) { _, response, error in
      let result: Result<Void, Error>
      if let error {
        result = .failure(error)
      } else if let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode)
      {
        result = .success(())
      } else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        result = .failure(OfficialPushRevocationError.requestFailed("服务器撤销失败（\(status)）"))
      }
      DispatchQueue.main.async { completion(result) }
    }.resume()
  }

  /// Removes the exact self-hosted registration before the user forgets the
  /// local configuration. The local remove action still succeeds if the
  /// server is unreachable; a future installation cannot authenticate with
  /// this device's private key.
  func revokeSelfHostedPush(
    _ configuration: SelfHostedPushConfiguration,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let deviceToken, !deviceToken.isEmpty else {
      completion(.success(()))
      return
    }
    let unregisterPath = configuration.unregisterPath ?? "/unregister"
    guard let url = try? SelfHostedPushConfiguration.endpointURL(
      serverURL: configuration.serverURL,
      path: unregisterPath
    ) else {
      completion(.failure(OfficialPushRevocationError.invalidServerURL))
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 15
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "deviceToken": deviceToken,
      "key": configuration.deviceKey,
    ])
    URLSession.shared.dataTask(with: request) { _, response, error in
      let result: Result<Void, Error>
      if let error {
        result = .failure(error)
      } else if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
        result = .success(())
      } else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        result = .failure(OfficialPushRevocationError.requestFailed("推送服务撤销失败（\(status)）"))
      }
      DispatchQueue.main.async { completion(result) }
    }.resume()
  }

  /// 处理 APNs Token 注册失败
  func didFailToRegisterForRemoteNotifications(error: Error) {
    #if !DREL_CONTAINER_ONLY
      print("[PushManager] Failed to register: \(error)")
    #endif
    // Dev-signed 包缺 aps-environment 时系统会返回原文含 "aps-environment" 的
    // 授权错误；对用户只呈现人话，技术细节保留在上面的日志里。
    let rawMessage = error.localizedDescription
    let message =
      rawMessage.contains("aps-environment")
      ? L10n.tr("official.push.error.entitlement")
      : rawMessage
    let completion = pendingOfficialRegistration?.completion
    pendingOfficialRegistration = nil
    if let pending = pendingSelfHostedRegistration {
      pendingSelfHostedRegistration = nil
      pending.completion(.failed(message))
    } else {
      completion?(.failed(message))
    }
  }

  #if !DREL_CONTAINER_ONLY
    private var isOfficialPushUITest: Bool {
      return ProcessInfo.processInfo.isWebBridgeKitUITesting
        && ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_STATE"] != nil
    }

    private func activateOfficialPushForUITest(
      completion: @escaping (OfficialPushActivationResult) -> Void
    ) {
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
    #if !DREL_CONTAINER_ONLY
      print("[PushManager] Received foreground notification")
    #endif
    // 可以展示一个自定义的 App 内通知 banner
  }

  /// 用户点击通知打开 App
  func handleNotificationTap(userInfo: [AnyHashable: Any], rootViewController: UIViewController?) {
    PushRouter.shared.handle(userInfo: userInfo, from: rootViewController)
  }
}
