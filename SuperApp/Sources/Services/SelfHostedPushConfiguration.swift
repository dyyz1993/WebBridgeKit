import Foundation

enum DrelPushRelayKind: String, Codable, Equatable, CaseIterable {
  case selfHostedDirect = "self-hosted-direct"
  case managedEncrypted = "managed-encrypted"

  var descriptorPath: String {
    switch self {
    case .selfHostedDirect: return "/.well-known/drel-push.json"
    case .managedEncrypted: return "/.well-known/drel-managed-push.json"
    }
  }

  var descriptorSchema: String {
    switch self {
    case .selfHostedDirect: return "drel.self-hosted-push.v1"
    case .managedEncrypted: return "drel.managed-encrypted-push.v1"
    }
  }

  var importHost: String {
    switch self {
    case .selfHostedDirect: return "self-hosted-push"
    case .managedEncrypted: return "managed-encrypted-push"
    }
  }

  static func fromImportHost(_ value: String?) -> DrelPushRelayKind? {
    guard let value else { return nil }
    return Self.allCases.first { $0.importHost == value.lowercased() }
  }
}

/// Stored separately from the official Drel service. Importing a self-hosted
/// endpoint never changes the official push address or its registration.
struct SelfHostedPushConfiguration: Codable, Equatable {
  let name: String
  let serverURL: String
  let registrationPath: String
  let pairingPath: String
  let deviceKey: String
  /// Optional preserves configurations written before managed encrypted push
  /// was introduced; those configurations remain direct self-hosted relays.
  let relayKind: DrelPushRelayKind?
  let unregisterPath: String?
  let recipientPath: String?
  let deliveryPath: String?
  let envelopeSchema: String?

  static let storageKey = "drel.selfhosted-push.configuration.v1"

  static func load() -> SelfHostedPushConfiguration? {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
    return try? JSONDecoder().decode(SelfHostedPushConfiguration.self, from: data)
  }

  func save() {
    UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.storageKey)
  }

  static func remove() {
    UserDefaults.standard.removeObject(forKey: storageKey)
  }

  struct Import {
    let serverURL: URL
    let pairingToken: String?
    let relayKind: DrelPushRelayKind
  }

  var resolvedRelayKind: DrelPushRelayKind { relayKind ?? .selfHostedDirect }

  func reconnectImportPayload() -> String {
    guard resolvedRelayKind == .managedEncrypted else { return serverURL }
    var components = URLComponents()
    components.scheme = "drel"
    components.host = resolvedRelayKind.importHost
    components.queryItems = [URLQueryItem(name: "server", value: serverURL)]
    return components.string ?? serverURL
  }

  static func parseImport(_ raw: String) throws -> Import {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let components = URLComponents(string: trimmed), components.scheme == "drel" {
      guard let relayKind = DrelPushRelayKind.fromImportHost(components.host) else {
        throw ImportError.invalidAddress
      }
      var values: [String: String] = [:]
      for item in components.queryItems ?? [] {
        guard values[item.name] == nil else { throw ImportError.invalidAddress }
        values[item.name] = item.value ?? ""
      }
      guard let server = values["server"], let url = URL(string: server) else {
        throw ImportError.invalidAddress
      }
      try validate(url)
      return Import(
        serverURL: url,
        pairingToken: values["token"].flatMap { $0.isEmpty ? nil : $0 },
        relayKind: relayKind
      )
    }
    guard let url = URL(string: trimmed) else { throw ImportError.invalidAddress }
    try validate(url)
    return Import(serverURL: url, pairingToken: nil, relayKind: .selfHostedDirect)
  }

  static func validate(_ url: URL) throws {
    #if DEBUG
      let validScheme = url.scheme == "https" || url.scheme == "http"
    #else
      let validScheme = url.scheme == "https"
    #endif
    guard validScheme, url.host != nil, url.user == nil, url.password == nil else {
      throw ImportError.invalidAddress
    }
  }

  /// A descriptor may choose only a relative endpoint on its own origin.
  /// Never concatenate an untrusted URL-shaped string to the configured
  /// server: `@attacker.example` would otherwise reinterpret the authority.
  static func validatedEndpointPath(_ raw: String) throws -> String {
    guard raw.hasPrefix("/"), !raw.hasPrefix("//"),
      let components = URLComponents(string: raw),
      components.scheme == nil, components.host == nil,
      components.user == nil, components.password == nil
    else {
      throw ImportError.invalidDescriptor
    }
    return raw
  }

  static func endpointURL(serverURL: String, path: String) throws -> URL {
    guard let base = URL(string: serverURL) else { throw ImportError.invalidAddress }
    let validatedPath = try validatedEndpointPath(path)
    guard let resolved = URL(string: validatedPath, relativeTo: base)?.absoluteURL,
      resolved.scheme?.lowercased() == base.scheme?.lowercased(),
      resolved.host?.lowercased() == base.host?.lowercased(),
      resolved.port == base.port
    else {
      throw ImportError.invalidDescriptor
    }
    return resolved
  }

  enum ImportError: LocalizedError {
    case invalidAddress, invalidDescriptor
    var errorDescription: String? {
      switch self {
      case .invalidAddress: return "请输入 HTTPS 服务器地址，或扫描部署页提供的 Drel 配置码。"
      case .invalidDescriptor: return "该地址不是兼容且已就绪的 Drel 推送服务。"
      }
    }
  }
}

struct SelfHostedPushDescriptor: Decodable {
  let schema: String
  let name: String
  let publicBaseURL: String
  let registrationPath: String
  let pairingPath: String
  let healthPath: String
  let unregisterPath: String?
  let recipientPath: String?
  let deliveryPath: String?
  let envelopeSchema: String?
}

struct SelfHostedPushHealthResponse: Decodable {
  let status: String
  let apnsReady: Bool?
}

struct SelfHostedPairingResponse: Decodable { let pairingToken: String }
