//
//  HTMLAppGatewayOnboarding.swift
//  WebBridgeKit
//

import CryptoKit
import Foundation

public protocol HTMLAppGatewayTransport: AnyObject {
    func get(_ url: URL, completion: @escaping (Result<(Data, Int), Error>) -> Void)
}

public final class HTMLAppGatewayURLSessionTransport: HTMLAppGatewayTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, completion: @escaping (Result<(Data, Int), Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(.success((data ?? Data(), statusCode)))
        }.resume()
    }
}

public struct HTMLAppGatewayValidationReport: Equatable {
    public let gateway: HTMLAppGatewayConfiguration
    public let manifests: [HTMLAppManifest]
    public let healthStatusCode: Int

    public init(gateway: HTMLAppGatewayConfiguration, manifests: [HTMLAppManifest], healthStatusCode: Int) {
        self.gateway = gateway
        self.manifests = manifests
        self.healthStatusCode = healthStatusCode
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

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Gateway configuration is invalid"
        case .invalidHealthResponse(let code): return "Gateway health check failed with HTTP \(code)"
        case .invalidManifestResponse(let code): return "Gateway manifest request failed with HTTP \(code)"
        case .malformedManifestResponse: return "Gateway returned an unsupported manifest response"
        case .missingTrustAnchor: return "Production gateway configuration requires keyId and an Ed25519 public key"
        case .invalidManifest(let appID): return "Gateway returned an invalid manifest for \(appID)"
        case .signatureVerificationFailed(let appID): return "Manifest signature verification failed for \(appID)"
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
        permissionLedger: HTMLAppPermissionLedger = HTMLAppPermissionLedger(),
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
            case .success((_, let statusCode)) where !(200..<300).contains(statusCode):
                completion(.failure(HTMLAppGatewayOnboardingError.invalidHealthResponse(statusCode)))
            case .success((_, let statusCode)):
                self.fetchManifests(from: manifestURL, gateway: gateway) { result in
                    completion(result.map {
                        HTMLAppGatewayValidationReport(gateway: gateway, manifests: $0, healthStatusCode: statusCode)
                    })
                }
            }
        }
    }

    public func activate(_ report: HTMLAppGatewayValidationReport) throws {
        let previousGateway = gatewayRegistry.activeGateway()
        let previousManifests = trustRegistry.registeredManifests()
        let newAppIDs = Set(report.manifests.map(\.appID))

        for manifest in report.manifests {
            let policy = try trustPolicy(for: report.gateway)
            try trustRegistry.register(manifest, trustPolicy: policy.registryPolicy)
        }
        for manifest in previousManifests where !newAppIDs.contains(manifest.appID) {
            try trustRegistry.unregister(appID: manifest.appID)
        }
        if let previousGateway, previousGateway != report.gateway {
            previousManifests.forEach { permissionLedger.revokeAll(appID: $0.appID) }
        }
        try gatewayRegistry.save(report.gateway, activate: true)
    }

    /// Removing the active gateway must also remove the trust and capability
    /// state that was established through it. Saved inactive gateways have no
    /// active manifests, so only their configuration is removed.
    public func removeGateway(id: String) throws {
        let isActiveGateway = gatewayRegistry.activeGateway()?.id == id
        if isActiveGateway {
            let manifests = trustRegistry.registeredManifests()
            for manifest in manifests {
                permissionLedger.revokeAll(appID: manifest.appID)
                try trustRegistry.unregister(appID: manifest.appID)
            }
        }
        try gatewayRegistry.remove(id: id)
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
            case .success((_, let code)) where !(200..<300).contains(code):
                completion(.failure(HTMLAppGatewayOnboardingError.invalidManifestResponse(code)))
            case .success((let data, _)):
                do {
                    let manifests = try self.decodeManifests(data)
                    try manifests.forEach { try self.validateTrust(of: $0, gateway: gateway) }
                    completion(.success(manifests))
                } catch {
                    completion(.failure(error))
                }
            }
        }
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
