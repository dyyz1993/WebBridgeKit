//
//  HTMLAppDeclaredIdentity.swift
//  WebBridgeKit
//
//  Page-declared application identity (Layer 2.5 local trust upgrade).
//
//  A web page can declare who it is via meta tags:
//    <meta name="webbridgekit-app-id" content="com.example.inventory">
//    <meta name="webbridgekit-app-name" content="库存工具">
//    <meta name="webbridgekit-capabilities" content="clipboard,camera">
//
//  Semantics:
//  - With a valid app-id the permission ledger key upgrades from
//    "local.{origin}" to "page.{app-id}" — grants become per-app on the
//    same origin instead of origin-wide. The "page." namespace prevents
//    a hostile page from claiming a gateway-registered app's real ID.
//    The origin remains part of the ledger subject, so a declared ID can
//    never inherit grants recorded for another origin.
//  - A declared capability list constrains requests: capabilities outside
//    the list are denied (mirrors gateway manifest semantics). An absent
//    or empty list keeps local-trust behavior (any capability may prompt).
//  - Pages without these metas are fully backward compatible.
//

import Foundation

public struct HTMLAppDeclaredIdentity: Equatable {
    /// Sanitized page-declared app ID (charset [A-Za-z0-9._-], ≤64 chars)
    public let appID: String
    /// Optional display name for the consent panel header
    public let appName: String?
    /// Declared capability allowlist; empty = unconstrained (prompt per use)
    public let capabilities: Set<HTMLAppCapability>

    /// Ledger/subject app ID used by the bridge when a declaration exists.
    public var namespacedAppID: String { "page.\(appID)" }

    /// Parses raw meta contents. Returns nil when no usable app-id is given
    /// (invalid IDs are dropped, not repaired — a typo'd ID silently switching
    /// identity would be worse than falling back to origin identity).
    public static func parse(appID: String?, appName: String?, capabilities: String?) -> HTMLAppDeclaredIdentity? {
        guard let rawID = appID?.trimmingCharacters(in: .whitespacesAndNewlines),
              isValidAppID(rawID) else { return nil }
        let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let caps = (capabilities ?? "")
            .split(separator: ",")
            .compactMap { HTMLAppCapability(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        return HTMLAppDeclaredIdentity(
            appID: rawID,
            appName: (name?.isEmpty == false) ? name : nil,
            capabilities: Set(caps)
        )
    }

    private static func isValidAppID(_ appID: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return !appID.isEmpty && appID.count <= 64 && appID.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// Reads the declaration metas from the front document.
    /// Executed via evaluateJavaScript on navigation finish.
    public static let extractionScript = """
    (function() {
        function meta(name) {
            var el = document.querySelector('meta[name="' + name + '"]');
            return el && el.content ? el.content : null;
        }
        return JSON.stringify({
            id: meta('webbridgekit-app-id'),
            name: meta('webbridgekit-app-name'),
            caps: meta('webbridgekit-capabilities')
        });
    })()
    """

    public static func parse(extractionResult: Any?) -> HTMLAppDeclaredIdentity? {
        guard let json = extractionResult as? String,
              let data = json.data(using: .utf8),
              let fields = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return parse(
            appID: fields["id"],
            appName: fields["name"],
            capabilities: fields["caps"]
        )
    }
}
