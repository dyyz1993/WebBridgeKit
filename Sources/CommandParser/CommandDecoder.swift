//
//  CommandDecoder.swift
//  WebBridgeKit
//

import Foundation
import CryptoKit

public protocol CommandDecoderProtocol: Sendable {
    var format: CommandFormat { get }
    func canDecode(_ input: String) -> Bool
    func decode(_ input: String) throws -> CommandRawPayload
}

public protocol CommandSignatureVerifier: Sendable {
    func verify(payload: CommandRawPayload, signature: String) -> Bool
}

public struct HMACSignatureVerifier: CommandSignatureVerifier {
    private let secretKey: SymmetricKey

    public init(secretKey: Data) {
        self.secretKey = SymmetricKey(data: secretKey)
    }

    public init(secretKeyHex: String) {
        let keyData = Data(hex: secretKeyHex)
        self.secretKey = SymmetricKey(data: keyData)
    }

    public func verify(payload: CommandRawPayload, signature: String) -> Bool {
        guard let signatureData = Data(hexString: signature) else { return false }
        let hmac = HMAC<SHA256>.authenticationCode(for: payload.data, using: secretKey)
        return Data(hmac) == signatureData
    }
}

public final class CommandDecoderRegistry: Sendable {
    public static let shared = CommandDecoderRegistry()

    private let decoders: [CommandFormat: any CommandDecoderProtocol]

    private init() {
        let decoderList: [any CommandDecoderProtocol] = [
            Base64CommandDecoder(),
            URLSchemeCommandDecoder(),
            PlainTextCommandDecoder()
        ]
        var map: [CommandFormat: any CommandDecoderProtocol] = [:]
        for decoder in decoderList {
            map[decoder.format] = decoder
        }
        self.decoders = map
    }

    public func findDecoder(for input: String) -> (any CommandDecoderProtocol)? {
        for (_, decoder) in decoders where decoder.canDecode(input) {
            return decoder
        }
        return nil
    }

    public func getDecoder(format: CommandFormat) -> (any CommandDecoderProtocol)? {
        decoders[format]
    }
}

public final class Base64CommandDecoder: CommandDecoderProtocol {
    public let format: CommandFormat = .base64

    public init() {}

    public func canDecode(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let base64Pattern = "^[A-Za-z0-9+/_-]+=*$"
        guard let regex = try? NSRegularExpression(pattern: base64Pattern) else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let match = regex.firstMatch(in: trimmed, range: range)
        return match != nil && trimmed.count >= 16
    }

    public func decode(_ input: String) throws -> CommandRawPayload {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64String = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - base64String.count % 4) % 4
        let padded = base64String + String(repeating: "=", count: paddingLength)

        guard let data = Data(base64Encoded: padded) else {
            throw CommandError.decodingFailed(reason: "Base64 decoding failed")
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let json = jsonObject as? [String: Any] else {
            throw CommandError.decodingFailed(reason: "Payload is not valid JSON")
        }

        let signature = json["sig"] as? String

        return CommandRawPayload(data: data, json: json, signature: signature)
    }
}

public final class URLSchemeCommandDecoder: CommandDecoderProtocol {
    public let format: CommandFormat = .urlScheme

    private let schemePrefix = "wbsk://command"

    public init() {}

    public func canDecode(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix(schemePrefix)
    }

    public func decode(_ input: String) throws -> CommandRawPayload {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URLComponents(string: trimmed),
              let queryItems = url.queryItems else {
            throw CommandError.decodingFailed(reason: "Invalid URL scheme format")
        }

        var dataBase64: String?
        var signature: String?

        for item in queryItems {
            if item.name == "data" {
                dataBase64 = item.value
            } else if item.name == "sig" {
                signature = item.value
            }
        }

        guard let dataBase64 = dataBase64 else {
            throw CommandError.decodingFailed(reason: "Missing 'data' parameter in URL scheme")
        }

        let base64String = dataBase64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = (4 - base64String.count % 4) % 4
        let padded = base64String + String(repeating: "=", count: paddingLength)

        guard let data = Data(base64Encoded: padded) else {
            throw CommandError.decodingFailed(reason: "Base64 decoding of 'data' parameter failed")
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let json = jsonObject as? [String: Any] else {
            throw CommandError.decodingFailed(reason: "Payload data is not valid JSON")
        }

        return CommandRawPayload(data: data, json: json, signature: signature)
    }
}

public final class PlainTextCommandDecoder: CommandDecoderProtocol {
    public let format: CommandFormat = .plainText

    private let prefix = "【WebBridgeKit】"

    public init() {}

    public func canDecode(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix(prefix)
    }

    public func decode(_ input: String) throws -> CommandRawPayload {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else {
            throw CommandError.invalidFormat(reason: "Missing command prefix")
        }

        let base64Part = String(trimmed.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !base64Part.isEmpty else {
            throw CommandError.invalidFormat(reason: "Empty payload after prefix")
        }

        let base64String = base64Part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = (4 - base64String.count % 4) % 4
        let padded = base64String + String(repeating: "=", count: paddingLength)

        guard let data = Data(base64Encoded: padded) else {
            throw CommandError.decodingFailed(reason: "Base64 decoding failed")
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let json = jsonObject as? [String: Any] else {
            throw CommandError.decodingFailed(reason: "Payload is not valid JSON")
        }

        let signature = json["sig"] as? String

        return CommandRawPayload(data: data, json: json, signature: signature)
    }
}

private extension Data {
    init?(hexString: String) {
        let clean = hexString.lowercased().replacingOccurrences(of: " ", with: "")
        guard clean.count % 2 == 0 else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }

    init(hex: String) {
        let clean = hex.lowercased().replacingOccurrences(of: " ", with: "")
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            if let byte = UInt8(clean[index..<next], radix: 16) {
                data.append(byte)
            }
            index = next
        }
        self = data
    }
}
