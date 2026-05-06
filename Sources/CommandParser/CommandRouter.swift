//
//  CommandRouter.swift
//  WebBridgeKit
//

import Foundation

public final class CommandRouter: Sendable {
    public static let shared = CommandRouter()

    public init() {}

    public func route(_ payload: CommandPayload) -> CommandRoute {
        if !payload.appid.isEmpty {
            return .cachedApp(appid: payload.appid)
        }

        if let url = payload.url, !url.isEmpty {
            if let parsed = URL(string: url),
               let scheme = parsed.scheme,
               scheme != "http" && scheme != "https" {
                return .deeplink(url: url)
            }
            return .url(url: url)
        }

        return .none
    }
}
