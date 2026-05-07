//
//  CommandHandler.swift
//  SuperApp
//
//  Created on 2026-05-06.
//

import Foundation
import UIKit
import WebBridgeKit

@MainActor
final class CommandHandler {

    static let shared = CommandHandler()

    private var lastProcessedClipboardHash: String?
    private var pendingPayload: CommandPayload?
    private weak var bannerViewController: UIViewController?

    private init() {}

    func checkClipboardOnForeground() {
        let clipboardText = ClipboardMonitor.shared.readClipboard()
        guard let text = clipboardText,
              ClipboardMonitor.shared.looksLikeCommand(text) else {
            dismissBanner()
            return
        }

        let currentHash = String(text.hashValue)
        guard currentHash != lastProcessedClipboardHash else { return }
        lastProcessedClipboardHash = currentHash

        Task {
            do {
                let payload = try await CommandParser.shared.parse(text)
                self.pendingPayload = payload
                self.showDetectionBanner(for: payload)
            } catch {
                Log.warning("CommandParser failed: \(error)", category: .general)
            }
        }
    }

    func handlePendingCommand() {
        guard let payload = pendingPayload else { return }
        pendingPayload = nil
        dismissBanner()
        clearClipboard()
        routeCommand(payload)
    }

    func dismissPendingCommand() {
        pendingPayload = nil
        dismissBanner()
    }

    private func routeCommand(_ payload: CommandPayload) {
        let route = CommandRouter.shared.route(payload)

        switch route {
        case .cachedApp(let appid):
            routeCachedApp(appid: appid, payload: payload)
        case .url(let urlString):
            routeURL(urlString)
        case .deeplink(let urlString):
            routeDeeplink(urlString)
        case .none:
            Log.warning("Command has no route target", category: .general)
        @unknown default:
            Log.warning("Unknown command route type", category: .general)
        }
    }

    private func routeCachedApp(appid: String, payload: CommandPayload) {
        if let urlString = payload.url, let url = URL(string: urlString) {
            WebBrowserManager.shared.openBrowser(url: url)
            return
        }

        let key = "manifest_\(appid)"
        if let cached = ManifestCacheManager.shared.getCachedManifest(for: key) {
            let entryPath = findEntryPath(in: cached.resources)
            if let relativePath = entryPath, let absoluteURL = cached.resources[relativePath], let url = URL(string: absoluteURL) {
                WebBrowserManager.shared.openBrowser(url: url)
            } else {
                showAlert(title: "口令解析成功", message: "应用 \(appid) 缓存中未找到入口页面")
            }
        } else {
            showAlert(title: "口令解析成功", message: "应用 \(appid) 未找到本地缓存，请先访问对应页面")
        }
    }

    private func findEntryPath(in resources: [String: String]) -> String? {
        let candidates = ["index.html", "index.htm", "/", "main.html", "app.html"]
        for candidate in candidates where resources[candidate] != nil {
            return candidate
        }
        return resources.keys.sorted().first
    }

    private func routeURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            showAlert(title: "错误", message: "无效的 URL: \(urlString)")
            return
        }
        WebBrowserManager.shared.openBrowser(url: url)
    }

    private func routeDeeplink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func clearClipboard() {
        UIPasteboard.general.string = ""
    }

    private func showDetectionBanner(for payload: CommandPayload) {
        guard let topVC = getTopViewController() else { return }

        let title = payload.title ?? payload.appid
        let message = "检测到口令，是否打开「\(title)」？"

        let alert = UIAlertController(title: "口令识别", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "打开", style: .default) { [weak self] _ in
            self?.handlePendingCommand()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismissPendingCommand()
        })

        topVC.present(alert, animated: true)
        bannerViewController = topVC
    }

    private func dismissBanner() {
        bannerViewController?.presentedViewController?.dismiss(animated: true)
        bannerViewController = nil
    }

    private func getTopViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            return nil
        }
        return findTop(from: root)
    }

    private func findTop(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return findTop(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return findTop(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTop(from: selected)
        }
        return vc
    }

    private func showAlert(title: String, message: String) {
        guard let topVC = getTopViewController() else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        topVC.present(alert, animated: true)
    }
}
