import Foundation

/// Parses Drel's external app-launch link: `drel://app?app_id=…&route=…&param_<name>=…`.
///
/// The link is the one URL-scheme surface Drel intentionally exposes. It never
/// carries a raw web URL — only an app ID (+ optional route + string
/// parameters) that must resolve against the gateway-signed trust registry at
/// open time, so an arbitrary link cannot turn Drel into a generic browser.
/// Parameter keys are prefixed `param_` to keep them out of the host's own
/// display-policy vocabulary (`mode`, `hideNavBar`, …); they reach the page
/// through the same `drel_param_*` query channel a push uses.
public struct DrelExternalAppLink: Equatable, Sendable {
    public let appID: String
    public let route: String?
    public let parameters: [String: String]

    public init(appID: String, route: String?, parameters: [String: String]) {
        self.appID = appID
        self.route = route
        self.parameters = parameters
    }

    public static func parse(_ url: URL) -> DrelExternalAppLink? {
        guard url.scheme?.lowercased() == "drel",
              url.host?.lowercased() == "app",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var appID = ""
        var route: String?
        var parameters: [String: String] = [:]
        for item in components.queryItems ?? [] {
            switch item.name {
            case "app_id":
                appID = item.value ?? ""
            case "route":
                route = item.value
            default:
                guard item.name.hasPrefix("param_") else { continue }
                let name = String(item.name.dropFirst("param_".count))
                guard !name.isEmpty else { continue }
                parameters[name] = item.value ?? ""
            }
        }
        guard !appID.isEmpty else { return nil }
        return DrelExternalAppLink(appID: appID, route: route, parameters: parameters)
    }
}
