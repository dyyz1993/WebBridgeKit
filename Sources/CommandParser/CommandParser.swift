//
//  CommandParser.swift
//  WebBridgeKit
//

import Foundation

public actor CommandParser {
    public static let shared = CommandParser()

    private let decoderRegistry: CommandDecoderRegistry
    private var signatureVerifier: (any CommandSignatureVerifier)?
    private var configuration: CommandParserConfiguration
    private var processedNonces: Set<String> = []
    private let maxNonceCacheSize = 1000

    init(
        configuration: CommandParserConfiguration = .default,
        decoderRegistry: CommandDecoderRegistry = .shared
    ) {
        self.configuration = configuration
        self.decoderRegistry = decoderRegistry
    }

    public func setConfiguration(_ config: CommandParserConfiguration) {
        self.configuration = config
    }

    public func registerSignatureVerifier(_ verifier: any CommandSignatureVerifier) {
        self.signatureVerifier = verifier
    }

    public func parse(_ input: String) throws -> CommandPayload {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw CommandError.emptyInput
        }

        guard trimmed.count <= configuration.maxPayloadSize else {
            throw CommandError.payloadTooLarge(size: trimmed.count, maxSize: configuration.maxPayloadSize)
        }

        guard let decoder = decoderRegistry.findDecoder(for: trimmed) else {
            throw CommandError.invalidFormat(reason: "No matching decoder found for input")
        }

        let rawPayload = try decoder.decode(trimmed)

        if configuration.enableSignatureVerification {
            try verifySignature(rawPayload)
        }

        let payload = try validateAndBuildPayload(from: rawPayload)

        if configuration.enableTimestampValidation {
            try validateTimestamp(payload)
        }

        try validateNonce(payload)

        return payload
    }

    public func parseFromClipboard() throws -> CommandPayload? {
        guard let text = ClipboardMonitor.shared.readClipboard() else {
            return nil
        }
        guard ClipboardMonitor.shared.looksLikeCommand(text) else {
            return nil
        }
        return try parse(text)
    }

    public func clearNonceCache() {
        processedNonces.removeAll()
    }

    private func verifySignature(_ rawPayload: CommandRawPayload) throws {
        guard let verifier = signatureVerifier else {
            Log.warning("No signature verifier registered, skipping verification", category: .general)
            return
        }

        guard let signature = rawPayload.signature, !signature.isEmpty else {
            throw CommandError.signatureVerificationFailed
        }

        let dataToVerify: Data
        if var json = rawPayload.json as? [String: Any] {
            json.removeValue(forKey: "sig")
            dataToVerify = (try? JSONSerialization.data(withJSONObject: json)) ?? rawPayload.data
        } else {
            dataToVerify = rawPayload.data
        }

        let signedPayload = CommandRawPayload(data: dataToVerify, json: rawPayload.json, signature: signature)

        guard verifier.verify(payload: signedPayload, signature: signature) else {
            throw CommandError.signatureVerificationFailed
        }
    }

    private func validateAndBuildPayload(from raw: CommandRawPayload) throws -> CommandPayload {
        let json = raw.json

        guard let appid = json["appid"] as? String, !appid.isEmpty else {
            throw CommandError.invalidPayload(reason: "Missing or empty 'appid' field")
        }

        guard isValidAppid(appid) else {
            throw CommandError.invalidAppid(appid)
        }

        if let url = json["url"] as? String, !url.isEmpty {
            guard isValidURL(url) else {
                throw CommandError.invalidURL(url)
            }
        }

        let url = json["url"] as? String
        let title = json["title"] as? String
        let icon = json["icon"] as? String
        let token = json["token"] as? String
        let timestamp = json["ts"] as? TimeInterval ?? json["timestamp"] as? TimeInterval
        let nonce = json["nonce"] as? String

        var extra: [String: String]?
        if let extraDict = json["extra"] as? [String: String] {
            extra = extraDict
        } else if let extraDict = json["extra"] as? [String: Any] {
            var converted: [String: String] = [:]
            for (key, value) in extraDict {
                converted[key] = String(describing: value)
            }
            extra = converted
        }

        return CommandPayload(
            appid: appid,
            url: url,
            title: title,
            icon: icon,
            token: token,
            extra: extra,
            timestamp: timestamp,
            nonce: nonce
        )
    }

    private func validateTimestamp(_ payload: CommandPayload) throws {
        guard let timestamp = payload.timestamp else { return }

        let now = Date().timeIntervalSince1970
        let age = abs(now - timestamp)

        if age > configuration.maxAge {
            throw CommandError.expiredCommand(age: age)
        }
    }

    private func validateNonce(_ payload: CommandPayload) throws {
        guard let nonce = payload.nonce else { return }

        guard !processedNonces.contains(nonce) else {
            throw CommandError.invalidPayload(reason: "Duplicate command (nonce reuse)")
        }

        processedNonces.insert(nonce)

        if processedNonces.count > maxNonceCacheSize {
            let excess = processedNonces.count - maxNonceCacheSize
            let toRemove = Array(processedNonces.prefix(excess))
            for n in toRemove {
                processedNonces.remove(n)
            }
        }
    }

    private func isValidAppid(_ appid: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return !appid.isEmpty
            && appid.count <= 64
            && appid.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return configuration.allowedSchemes.contains(scheme)
    }
}
