import Foundation
import Hummingbird

struct CommandToken: Codable, Sendable {
    let id: String
    let payload: CommandPayload
    let signature: String
    let createdAt: String
    let expiresAt: String?

    struct CommandPayload: Codable, Sendable {
        let type: CommandType
        let data: String
        let format: CommandFormat

        enum CommandType: String, Codable, Sendable {
            case urlScheme
            case base64
            case plainText
            case json
        }

        enum CommandFormat: String, Codable, Sendable {
            case urlScheme
            case base64
            case plainText
        }
    }
}

struct CommandGenerateRequest: Codable, Sendable {
    let type: CommandToken.CommandPayload.CommandType
    let data: String
    let format: CommandToken.CommandPayload.CommandFormat?
    let ttlSeconds: Int?
}

struct CommandGenerateResponse: ResponseEncodable, Sendable {
    let id: String
    let token: String
    let url: String
    let signature: String
}

struct CommandResolveResponse: ResponseEncodable, Sendable {
    let id: String
    let payload: CommandToken.CommandPayload
    let format: CommandToken.CommandPayload.CommandFormat
    let output: String
}
