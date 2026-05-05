import Foundation

/// Routes messages to appropriate targets based on payload content
public struct MessageRouter: Sendable {
    /// Custom route resolver
    public var customResolver: (@Sendable (MessagePayload) -> RouteTarget?)?

    public init() {}

    /// Route a message payload to its target
    /// - Parameter payload: The message payload to route
    /// - Returns: Route target
    public func route(payload: MessagePayload) -> RouteTarget {
        // 1. Try custom resolver first
        if let custom = customResolver?(payload) {
            return custom
        }

        // 2. Route by appId (mini app)
        if let appId = payload.targetAppId, !appId.isEmpty {
            return RouteTarget(
                type: .appId,
                destination: appId,
                mode: payload.targetMode,
                params: payload.userInfo
            )
        }

        // 3. Route by URL
        if let urlString = payload.targetURL, let url = URL(string: urlString), !urlString.isEmpty {
            // Check if it's a deep link
            if url.scheme != "http" && url.scheme != "https" {
                return RouteTarget(
                    type: .deeplink,
                    destination: urlString,
                    mode: payload.targetMode,
                    params: payload.userInfo
                )
            }

            return RouteTarget(
                type: .url,
                destination: urlString,
                mode: payload.targetMode,
                params: payload.userInfo
            )
        }

        // 4. Try to extract route from userInfo
        if let userInfo = payload.userInfo {
            if let appId = userInfo["appid"], !appId.isEmpty {
                return RouteTarget(
                    type: .appId,
                    destination: appId,
                    mode: userInfo["mode"],
                    params: userInfo
                )
            }

            if let url = userInfo["url"], !url.isEmpty {
                return RouteTarget(
                    type: .url,
                    destination: url,
                    mode: userInfo["mode"],
                    params: userInfo
                )
            }
        }

        // 5. No route
        return RouteTarget(type: .none, destination: "")
    }

    /// Route a push notification userInfo dictionary
    /// - Parameter userInfo: APNs userInfo dictionary
    /// - Returns: Route target
    public func route(userInfo: [AnyHashable: Any]) -> RouteTarget {
        let appId = userInfo["appid"] as? String
        let url = userInfo["url"] as? String
        let mode = userInfo["mode"] as? String

        if let appId = appId, !appId.isEmpty {
            return RouteTarget(
                type: .appId,
                destination: appId,
                mode: mode,
                params: userInfo as? [String: String]
            )
        }

        if let url = url, !url.isEmpty {
            return RouteTarget(
                type: .url,
                destination: url,
                mode: mode,
                params: userInfo as? [String: String]
            )
        }

        return RouteTarget(type: .none, destination: "")
    }
}
