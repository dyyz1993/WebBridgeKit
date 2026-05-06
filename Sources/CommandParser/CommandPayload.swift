//
//  CommandPayload.swift
//  WebBridgeKit
//

import Foundation

public struct CommandPayload: Codable, Sendable, Equatable {
    public let appid: String
    public let url: String?
    public let title: String?
    public let icon: String?
    public let token: String?
    public let extra: [String: String]?
    public let timestamp: TimeInterval?
    public let nonce: String?

    public init(
        appid: String,
        url: String? = nil,
        title: String? = nil,
        icon: String? = nil,
        token: String? = nil,
        extra: [String: String]? = nil,
        timestamp: TimeInterval? = nil,
        nonce: String? = nil
    ) {
        self.appid = appid
        self.url = url
        self.title = title
        self.icon = icon
        self.token = token
        self.extra = extra
        self.timestamp = timestamp
        self.nonce = nonce
    }

    public var hasURL: Bool {
        guard let url = url, !url.isEmpty else { return false }
        return true
    }

    public var hasToken: Bool {
        guard let token = token, !token.isEmpty else { return false }
        return true
    }
}

public struct CommandRawPayload: Sendable {
    public let data: Data
    public let json: [String: Any]
    public let signature: String?

    public init(data: Data, json: [String: Any], signature: String? = nil) {
        self.data = data
        self.json = json
        self.signature = signature
    }
}

public enum CommandFormat: String, Sendable, CaseIterable {
    case base64
    case urlScheme
    case plainText
}

public enum CommandError: Error, Sendable, LocalizedError {
    case invalidFormat(reason: String)
    case invalidPayload(reason: String)
    case signatureVerificationFailed
    case expiredCommand(age: TimeInterval)
    case payloadTooLarge(size: Int, maxSize: Int)
    case invalidAppid(String)
    case invalidURL(String)
    case decodingFailed(reason: String)
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let reason):
            return "Invalid command format: \(reason)"
        case .invalidPayload(let reason):
            return "Invalid command payload: \(reason)"
        case .signatureVerificationFailed:
            return "Command signature verification failed"
        case .expiredCommand(let age):
            return "Command expired (age: \(Int(age))s)"
        case .payloadTooLarge(let size, let maxSize):
            return "Command payload too large (\(size) > \(maxSize))"
        case .invalidAppid(let id):
            return "Invalid appid: \(id)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .decodingFailed(let reason):
            return "Decoding failed: \(reason)"
        case .emptyInput:
            return "Empty command input"
        }
    }
}

public struct CommandParserConfiguration: Sendable {
    public var maxPayloadSize: Int
    public var maxAge: TimeInterval
    public var allowedSchemes: Set<String>
    public var commandPrefix: String
    public var urlSchemePrefix: String
    public var enableSignatureVerification: Bool
    public var enableTimestampValidation: Bool

    public static let `default` = CommandParserConfiguration()

    public init(
        maxPayloadSize: Int = 4096,
        maxAge: TimeInterval = 300,
        allowedSchemes: Set<String> = ["http", "https"],
        commandPrefix: String = "【WebBridgeKit】",
        urlSchemePrefix: String = "wbsk://command",
        enableSignatureVerification: Bool = true,
        enableTimestampValidation: Bool = true
    ) {
        self.maxPayloadSize = maxPayloadSize
        self.maxAge = maxAge
        self.allowedSchemes = allowedSchemes
        self.commandPrefix = commandPrefix
        self.urlSchemePrefix = urlSchemePrefix
        self.enableSignatureVerification = enableSignatureVerification
        self.enableTimestampValidation = enableTimestampValidation
    }
}

public enum CommandRoute: Sendable, Equatable {
    case cachedApp(appid: String)
    case url(url: String)
    case deeplink(url: String)
    case none
}
