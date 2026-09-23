import Foundation
import UIKit
import WebBridgeKit

/// The single presentation rule for opening a stored URL (favorite or recent
/// item). A URL that resolves to a registered HTML app reopens that app the
/// way it was experienced — immersive with the manifest loader — so favoriting
/// an app and reopening it from the favorites page or the home grid stays one
/// continuous app experience. Everything else remains a normal web page.
enum DrelFavoriteOpenPolicy {

    static func open(_ url: URL, from viewController: UIViewController?) {
        let registry = HTMLAppRuntimeCenter.shared.trustRegistry
        if let manifest = registry.registeredApp(matching: url)
            ?? registeredAppByEntryDirectory(url: url, manifests: registry.registeredManifests()),
           let entry = URL(string: manifest.startURL) {
            WebBrowserManager.shared.openBrowser(
                url: entry,
                params: WebBrowserParams(displayMode: .immersive, useManifestLoader: true),
                from: viewController
            )
            return
        }
        // 未注册 = 普通 HTTPS 网页：必须显式关掉 manifest loader
        // （WebBrowserParams 默认 true），否则 loader 的自定义 scheme
        // 渲染会打挂普通页面的 JS 引导，形态也会从「返回+星标」变成「✕+菜单」。
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal, useManifestLoader: false),
            from: viewController
        )
    }

    /// 收藏夹里存的应用入口可能是「目录形态」：同一页面从不同入口收藏，
    /// 落库的 URL 形态不一致（推送 url/网页星标存当前地址 `/test/template/v1/`，
    /// 沉浸胶囊存签名 startURL `.../index.html`）。精确匹配会漏掉目录形态，
    /// 导致全屏收藏的应用从收藏夹打开回落普通模式。这里按「startURL 去掉
    /// 入口文件名后与收藏 URL 相等」补一刀；其余路径不做模糊匹配
    /// （drel://app 深链仍要求精确 route，安全边界不变）。
    private static func registeredAppByEntryDirectory(
        url: URL,
        manifests: [HTMLAppManifest]
    ) -> HTMLAppManifest? {
        func normalizedOriginAndPath(_ value: String) -> String? {
            guard let parsed = URL(string: value),
                  let scheme = parsed.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  let host = parsed.host?.lowercased() else { return nil }
            let port = parsed.port.map { ":\($0)" } ?? ""
            var path = parsed.path
            if path.hasSuffix("/") { path.removeLast() }
            return "\(scheme)://\(host)\(port)\(path)"
        }

        guard let target = normalizedOriginAndPath(url.absoluteString) else { return nil }
        let entryFileNames: Set<String> = ["index.html", "index.htm", "main.html", "default.html"]
        for manifest in manifests {
            guard let start = URL(string: manifest.startURL),
                  entryFileNames.contains(start.lastPathComponent.lowercased()) else { continue }
            if normalizedOriginAndPath(start.deletingLastPathComponent().absoluteString) == target {
                return manifest
            }
        }
        return nil
    }
}
