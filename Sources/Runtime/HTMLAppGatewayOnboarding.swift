//
//  HTMLAppGatewayOnboarding.swift
//  WebBridgeKit
//

import CryptoKit
import Foundation

public protocol HTMLAppGatewayTransport: AnyObject {
    func get(_ url: URL, completion: @escaping (Result<HTMLAppGatewayTransportResponse, Error>) -> Void)
}

public struct HTMLAppGatewayTransportResponse: Equatable {
    public let data: Data
    public let statusCode: Int
    public let finalURL: URL

    public init(data: Data, statusCode: Int, finalURL: URL) {
        self.data = data
        self.statusCode = statusCode
        self.finalURL = finalURL
    }
}

public final class HTMLAppGatewayURLSessionTransport: HTMLAppGatewayTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, completion: @escaping (Result<HTMLAppGatewayTransportResponse, Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            completion(.success(HTMLAppGatewayTransportResponse(
                data: data ?? Data(),
                statusCode: statusCode,
                finalURL: httpResponse?.url ?? url
            )))
        }.resume()
    }
}

public struct HTMLAppGatewayValidationReport: Equatable {
    public struct Check: Equatable {
        public enum Status: String { case passed, failed }
        public let name: String
        public let status: Status
        public let detail: String
    }
    public let gateway: HTMLAppGatewayConfiguration
    public let manifests: [HTMLAppManifest]
    public let healthStatusCode: Int
    public let checks: [Check]

    public var displayName: String { gateway.name }
    public var host: String { URL(string: gateway.baseURL)?.host ?? gateway.baseURL }
    public var healthEndpoint: String { gateway.healthURL?.absoluteString ?? gateway.healthPath }
    public var manifestEndpoint: String { gateway.manifestURL?.absoluteString ?? gateway.manifestPath }
    public var publicKeyID: String? { gateway.publicKeyID }
    public var applicationCount: Int { manifests.count }

    public init(
        gateway: HTMLAppGatewayConfiguration,
        manifests: [HTMLAppManifest],
        healthStatusCode: Int,
        checks: [Check]? = nil
    ) {
        self.gateway = gateway
        self.manifests = manifests
        self.healthStatusCode = healthStatusCode
        self.checks = checks ?? [
            Check(name: "health", status: .passed, detail: "HTTP \(healthStatusCode)"),
            Check(name: "manifests", status: .passed, detail: "\(manifests.count) verified")
        ]
    }
}

public enum HTMLAppGatewayOnboardingError: Error, Equatable, LocalizedError {
    case invalidConfiguration
    case invalidHealthResponse(Int)
    case invalidManifestResponse(Int)
    case malformedManifestResponse
    case missingTrustAnchor
    case invalidManifest(String)
    case signatureVerificationFailed(String)
    case malformedHealthResponse
    case crossOriginRedirect
    case persistenceFailed

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Gateway configuration is invalid"
        case .invalidHealthResponse(let code): return "Gateway health check failed with HTTP \(code)"
        case .invalidManifestResponse(let code): return "Gateway manifest request failed with HTTP \(code)"
        case .malformedManifestResponse: return "Gateway returned an unsupported manifest response"
        case .missingTrustAnchor: return "Production gateway configuration requires keyId and an Ed25519 public key"
        case .invalidManifest(let appID): return "Gateway returned an invalid manifest for \(appID)"
        case .signatureVerificationFailed(let appID): return "Manifest signature verification failed for \(appID)"
        case .malformedHealthResponse: return "Gateway health response must be JSON with status ok"
        case .crossOriginRedirect: return "Gateway redirected outside the configured origin"
        case .persistenceFailed: return "Gateway activation could not be persisted and was rolled back"
        }
    }
}

public final class HTMLAppGatewayOnboardingService {
    private struct ManifestEnvelope: Decodable {
        let manifests: [HTMLAppManifest]
    }

    private let gatewayRegistry: HTMLAppGatewayRegistry
    private let trustRegistry: HTMLAppTrustRegistry
    private let permissionLedger: HTMLAppPermissionLedger
    private let transport: HTMLAppGatewayTransport
    private let allowsDevelopmentMode: Bool

    public init(
        gatewayRegistry: HTMLAppGatewayRegistry,
        trustRegistry: HTMLAppTrustRegistry = HTMLAppTrustRegistry(),
        permissionLedger: HTMLAppPermissionLedger = .shared,
        transport: HTMLAppGatewayTransport = HTMLAppGatewayURLSessionTransport(),
        allowsDevelopmentMode: Bool = false
    ) {
        self.gatewayRegistry = gatewayRegistry
        self.trustRegistry = trustRegistry
        self.permissionLedger = permissionLedger
        self.transport = transport
        self.allowsDevelopmentMode = allowsDevelopmentMode
    }

    public func validate(
        _ gateway: HTMLAppGatewayConfiguration,
        completion: @escaping (Result<HTMLAppGatewayValidationReport, Error>) -> Void
    ) {
        guard gateway.validate(allowsDevelopmentHTTP: allowsDevelopmentMode).isValid,
              let healthURL = gateway.healthURL,
              let manifestURL = gateway.manifestURL else {
            completion(.failure(HTMLAppGatewayOnboardingError.invalidConfiguration))
            return
        }
        do {
            _ = try trustPolicy(for: gateway)
        } catch {
            completion(.failure(error))
            return
        }

        transport.get(healthURL) { [weak self] healthResult in
            guard let self else { return }
            switch healthResult {
            case .failure(let error): completion(.failure(error))
            case .success(let response) where !self.isSameOrigin(response.finalURL, gateway: gateway):
                completion(.failure(HTMLAppGatewayOnboardingError.crossOriginRedirect))
            case .success(let response) where !(200..<300).contains(response.statusCode):
                completion(.failure(HTMLAppGatewayOnboardingError.invalidHealthResponse(response.statusCode)))
            case .success(let response) where !self.isValidHealthResponse(response.data):
                completion(.failure(HTMLAppGatewayOnboardingError.malformedHealthResponse))
            case .success(let response):
                self.fetchManifests(from: manifestURL, gateway: gateway) { result in
                    completion(result.map {
                        HTMLAppGatewayValidationReport(gateway: gateway, manifests: $0, healthStatusCode: response.statusCode)
                    })
                }
            }
        }
    }

    public func activate(_ report: HTMLAppGatewayValidationReport) throws {
        let previousGateway = gatewayRegistry.activeGateway()
        let previousManifests = trustRegistry.registeredManifests()
        let previousGrants = permissionLedger.allGrants()
        let policy = try trustPolicy(for: report.gateway)
        let identityChanged = previousGateway.map { Self.identity(of: $0) != Self.identity(of: report.gateway) } ?? false
        let manifestsByAppID = Dictionary(uniqueKeysWithValues: report.manifests.map { ($0.appID, $0) })
        let replacementGrants = identityChanged
            ? []
            : previousGrants.filter { grant in
                guard let manifest = manifestsByAppID[grant.appID],
                      manifest.declares(grant.capability) else { return false }
                return manifest.allowedOrigins
                    .compactMap(HTMLAppOrigin.canonicalDeclaredOrigin)
                    .contains(grant.origin)
            }

        do {
            try trustRegistry.replaceAll(report.manifests, trustPolicy: policy.registryPolicy)
            try permissionLedger.replaceAll(replacementGrants)
            try gatewayRegistry.save(report.gateway, activate: true)
        } catch {
            try? trustRegistry.replaceAll(previousManifests)
            try? permissionLedger.replaceAll(previousGrants)
            if let previousGateway { try? gatewayRegistry.save(previousGateway, activate: true) }
            throw HTMLAppGatewayOnboardingError.persistenceFailed
        }
    }

    /// Removing the active gateway must also remove the trust and capability
    /// state that was established through it. Saved inactive gateways have no
    /// active manifests, so only their configuration is removed.
    public func removeGateway(id: String) throws {
        let isActiveGateway = gatewayRegistry.activeGateway()?.id == id
        guard isActiveGateway else {
            try gatewayRegistry.remove(id: id)
            return
        }
        let previousGateway = gatewayRegistry.activeGateway()
        let previousManifests = trustRegistry.registeredManifests()
        let previousGrants = permissionLedger.allGrants()
        do {
            try trustRegistry.replaceAll([])
            try permissionLedger.replaceAll([])
            try gatewayRegistry.remove(id: id)
        } catch {
            try? trustRegistry.replaceAll(previousManifests)
            try? permissionLedger.replaceAll(previousGrants)
            if let previousGateway {
                try? gatewayRegistry.save(previousGateway, activate: true)
            }
            throw HTMLAppGatewayOnboardingError.persistenceFailed
        }
    }

    private func fetchManifests(
        from url: URL,
        gateway: HTMLAppGatewayConfiguration,
        completion: @escaping (Result<[HTMLAppManifest], Error>) -> Void
    ) {
        transport.get(url) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let response) where !self.isSameOrigin(response.finalURL, gateway: gateway):
                completion(.failure(HTMLAppGatewayOnboardingError.crossOriginRedirect))
            case .success(let response) where !(200..<300).contains(response.statusCode):
                completion(.failure(HTMLAppGatewayOnboardingError.invalidManifestResponse(response.statusCode)))
            case .success(let response):
                do {
                    let manifests = try self.decodeManifests(response.data)
                    try manifests.forEach { try self.validateTrust(of: $0, gateway: gateway) }
                    completion(.success(manifests))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func isSameOrigin(_ url: URL, gateway: HTMLAppGatewayConfiguration) -> Bool {
        guard let baseURL = URL(string: gateway.baseURL) else { return false }
        return url.scheme?.lowercased() == baseURL.scheme?.lowercased()
            && url.host?.lowercased() == baseURL.host?.lowercased()
            && url.port == baseURL.port
    }

    private func isValidHealthResponse(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let status = dictionary["status"] as? String else { return false }
        if let schemaVersion = dictionary["schemaVersion"] as? String, schemaVersion != "1" {
            return false
        }
        return status.lowercased() == "ok"
    }

    private static func identity(of gateway: HTMLAppGatewayConfiguration) -> String {
        "\(gateway.baseURL.lowercased())|\(gateway.publicKeyID ?? "")|\(gateway.publicKey ?? "")"
    }

    private func decodeManifests(_ data: Data) throws -> [HTMLAppManifest] {
        let decoder = JSONDecoder()
        if let manifest = try? decoder.decode(HTMLAppManifest.self, from: data) { return [manifest] }
        if let manifests = try? decoder.decode([HTMLAppManifest].self, from: data) { return manifests }
        if let envelope = try? decoder.decode(ManifestEnvelope.self, from: data) { return envelope.manifests }
        throw HTMLAppGatewayOnboardingError.malformedManifestResponse
    }

    private func validateTrust(
        of manifest: HTMLAppManifest,
        gateway: HTMLAppGatewayConfiguration
    ) throws {
        guard manifest.validate(requiringSignature: !allowsDevelopmentMode).isValid else {
            throw HTMLAppGatewayOnboardingError.invalidManifest(manifest.appID)
        }
        if allowsDevelopmentMode && manifest.signature == nil { return }
        let policy = try trustPolicy(for: gateway)
        guard policy.verify(manifest) else {
            throw HTMLAppGatewayOnboardingError.signatureVerificationFailed(manifest.appID)
        }
    }

    private func trustPolicy(for gateway: HTMLAppGatewayConfiguration) throws -> GatewayTrustPolicy {
        if allowsDevelopmentMode && gateway.publicKey == nil {
            return GatewayTrustPolicy(registryPolicy: .development, verify: { $0.validate().isValid })
        }
        guard let keyID = gateway.publicKeyID,
              let publicKeyValue = gateway.publicKey,
              let publicKeyData = Self.decodeBase64URL(publicKeyValue),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
            throw HTMLAppGatewayOnboardingError.missingTrustAnchor
        }
        let verifier: (HTMLAppManifest) -> Bool = { manifest in
            guard let signature = manifest.signature,
                  signature.keyID == keyID,
                  let signatureData = Self.decodeBase64URL(signature.value),
                  let payload = try? Self.canonicalUnsignedPayload(manifest) else { return false }
            return publicKey.isValidSignature(signatureData, for: payload)
        }
        return GatewayTrustPolicy(registryPolicy: .managed(signatureVerifier: verifier), verify: verifier)
    }

    private struct GatewayTrustPolicy {
        let registryPolicy: HTMLAppTrustPolicy
        let verify: (HTMLAppManifest) -> Bool
    }

    private static func canonicalUnsignedPayload(_ manifest: HTMLAppManifest) throws -> Data {
        let unsigned = HTMLAppManifest(
            schemaVersion: manifest.schemaVersion,
            appID: manifest.appID,
            name: manifest.name,
            startURL: manifest.startURL,
            allowedOrigins: manifest.allowedOrigins,
            capabilities: manifest.capabilities,
            routes: manifest.routes,
            cache: manifest.cache
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(unsigned)
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}
