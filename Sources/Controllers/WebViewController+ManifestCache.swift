//
//  WebViewController+ManifestCache.swift
//  WebBridgeKit
//

import UIKit
import WebKit

// MARK: - Manifest Cache Integration
extension WebViewController {

    /// 下载并使用 Manifest
    /// - Parameters:
    ///   - manifestURL: manifest.json 的 URL
    ///   - pageURL: 页面 URL
    func downloadAndUseManifest(from manifestURL: URL, pageURL: URL) {
        print("📥 [ManifestCache] Downloading manifest from: \(manifestURL.absoluteString)")

        let task = URLSession.shared.dataTask(with: manifestURL) { [weak self] data, _, error in
            guard let self else { return }

            if let error = error {
                print("❌ [ManifestCache] Failed to download manifest: \(error.localizedDescription)")
                // 回退到普通加载
                Task { @MainActor [weak self] in
                    self?.fallbackToNormalLoad(pageURL, error: error)
                }
                return
            }

            guard let data else {
                print("❌ [ManifestCache] Manifest data is empty")
                let emptyError = NSError(domain: "WebBridgeKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Manifest data is empty"])
                Task { @MainActor [weak self] in
                    self?.fallbackToNormalLoad(pageURL, error: emptyError)
                }
                return
            }

            do {
                // 解析 manifest
                let manifest = try JSONDecoder().decode(PersistentManifestLoader.WebManifest.self, from: data)

                print("✅ [ManifestCache] Manifest downloaded successfully")
                print("   - Persistent: \(manifest.persistent)")
                print("   - Resources: \(manifest.resources.count)")
                print("   - Version: \(manifest.version ?? "N/A")")

                // 根据 persistent 字段选择加载策略
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if manifest.persistent {
                        print("🔥 [ManifestCache] Using PERSISTENT mode (download all resources first)")
                        self.usePersistentMode(pageURL: pageURL, manifest: manifest)
                    } else {
                        print("⚡ [ManifestCache] Using LAZY mode (load HTML immediately, background download)")
                        self.useLazyMode(pageURL: pageURL, manifest: manifest)
                    }
                }

            } catch {
                print("❌ [ManifestCache] Failed to decode manifest: \(error.localizedDescription)")
                // 回退到普通加载
                Task { @MainActor [weak self] in
                    self?.fallbackToNormalLoad(pageURL, error: error)
                }
            }
        }

        task.resume()
    }

    /// 使用持久化模式（下载所有资源后再加载）
    private func usePersistentMode(pageURL: URL, manifest: PersistentManifestLoader.WebManifest) {
        // 找到合适的 view controller 来显示进度弹窗
        let presentingViewController: UIViewController
        if let navController = navigationController,
           let topVC = navController.topViewController {
            presentingViewController = topVC
        } else if let parentVC = parent {
            presentingViewController = parentVC
        } else {
            presentingViewController = self
        }

        print("💾 [ManifestCache] Starting persistent mode download")

        PersistentManifestLoader.load(
            url: pageURL,
            in: webView,
            from: presentingViewController
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success:
                    print("✅ [ManifestCache] Persistent mode load completed successfully")
                case .failure(let error):
                    print("❌ [ManifestCache] Persistent mode failed: \(error.localizedDescription)")
                    // 回退到普通加载
                    self.fallbackToNormalLoad(pageURL, error: error)
                }
            }
        }
    }

    /// 使用懒加载模式（立即加载 HTML，后台下载资源）
    private func useLazyMode(pageURL: URL, manifest: PersistentManifestLoader.WebManifest) {
        print("⚡ [ManifestCache] Starting lazy mode load")

        // 将 WebManifest 转换为 LazyManifestLoader.WebManifest
        _ = LazyManifestLoader.WebManifest(
            persistent: manifest.persistent,
            resources: manifest.resources,
            version: manifest.version,
            appid: manifest.appid,
            name: manifest.name,
            icon: manifest.icon
        )

        LazyManifestLoader.load(
            url: pageURL,
            in: webView
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success:
                    print("✅ [ManifestCache] Lazy mode load completed successfully")
                case .failure(let error):
                    print("❌ [ManifestCache] Lazy mode failed: \(error.localizedDescription)")
                    // 回退到普通加载
                    self.fallbackToNormalLoad(pageURL, error: error)
                }
            }
        }
    }

    /// 回退到普通加载模式
    func fallbackToNormalLoad(_ url: URL, error: Error? = nil) {
        print("⏭️ [ManifestCache] Falling back to normal load")

        // 如果提供了错误信息，且是自定义协议 URL，则显示错误页面
        if let error = error, url.scheme == customScheme || url.scheme == "wb-resource" {
            showErrorPage(url: url, error: error)
            return
        }

        webView.load(URLRequest(url: url))
        print("🌐 [BarkWebVC] Loading: \(url) (fallback mode)")

        // 页面加载完成后自动生成缩略图
        generateThumbnailAfterLoad(url: url)
    }

    /// 显示资源加载错误页面
    private func showErrorPage(url: URL, error: Error) {
        let title = "WebBridge 资源加载失败"
        let urlString = url.absoluteString
        let errorMessage = error.localizedDescription

        let errorHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body { font-family: -apple-system, sans-serif; background-color: #f8f9fa; margin: 0; padding: 20px; color: #2d3748; line-height: 1.5; }
                .container { max-width: 600px; margin: 40px auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-top: 6px solid #e53e3e; }
                h1 { color: #c53030; font-size: 22px; margin-top: 0; display: flex; align-items: center; }
                .icon { font-size: 28px; margin-right: 12px; }
                .info-box { background: #fff5f5; border: 1px solid #feb2b2; padding: 15px; border-radius: 8px; margin: 20px 0; word-break: break-all; }
                .label { font-weight: bold; color: #742a2a; display: block; margin-bottom: 5px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
                code { background: #edf2f7; padding: 3px 6px; border-radius: 4px; font-family: "SFMono-Regular", Consolas, monospace; font-size: 13px; color: #1a202c; }
                .footer { margin-top: 30px; font-size: 14px; color: #4a5568; border-top: 1px solid #edf2f7; padding-top: 20px; }
                ul { padding-left: 20px; margin-top: 10px; }
                li { margin-bottom: 8px; }
                .btn { display: inline-block; background: #4a5568; color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none; margin-top: 15px; font-size: 14px; cursor: pointer; border: none; }
                .btn:hover { background: #2d3748; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1><span class="icon">🚫</span>资源加载失败</h1>
                <p>在处理 manifest 缓存加载时遇到了错误，无法加载目标页面。</p>

                <div class="info-box">
                    <span class="label">请求地址 (Request URL):</span>
                    <code>\(urlString)</code>
                </div>

                <div class="info-box">
                    <span class="label">错误原因 (Error):</span>
                    <code>\(errorMessage)</code>
                </div>

                <div class="footer">
                    <span class="label">排查建议:</span>
                    <ul>
                        <li>检查网络连接是否正常，确保能够下载 <code>manifest.json</code>。</li>
                        <li>确认服务器上的 <code>manifest.json</code> 格式是否正确。</li>
                        <li>检查本地缓存策略配置是否与服务器一致。</li>
                        <li>尝试在设置中清理缓存后重试。</li>
                    </ul>
                    <button onclick="window.location.reload()" class="btn">重试加载 (Reload)</button>
                </div>
            </div>
        </body>
        </html>
        """

        self.webView.loadHTMLString(errorHTML, baseURL: url)
        print("⚠️ [BarkWebVC] Loaded error page for: \(url.absoluteString)")
    }

    // MARK: - Manifest Cache Helper Methods

    /// Load a local HTML file with manifest-based resource mapping
    /// - Parameters:
    ///   - htmlName: HTML file name (without extension)
    ///   - manifestName: Manifest JSON file name (without extension)
    public func loadLocalHTML(withManifest htmlName: String, manifestName: String = "manifest") {
        // Ensure view is loaded
        _ = view

        guard Bundle.main.path(forResource: htmlName, ofType: "html") != nil else {
            print("❌ [BarkWebVC] HTML file not found: \(htmlName).html")
            return
        }

        guard let manifestPath = Bundle.main.path(forResource: manifestName, ofType: "json") else {
            print("❌ [BarkWebVC] Manifest file not found: \(manifestName).json")
            return
        }

        do {
            let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
            let manifest = try JSONDecoder().decode([String: String].self, from: manifestData)

            // Register manifest with ManifestURLSchemeHandler
            if let handler = webView.configuration.urlSchemeHandler(forURLScheme: customScheme) as? ManifestURLSchemeHandler {
                handler.registerManifest(forPage: htmlName, manifest: manifest)
                print("✅ [BarkWebVC] Registered manifest for: \(htmlName)")
            } else {
                print("⚠️ [BarkWebVC] ManifestURLSchemeHandler not found")
            }

            // Load HTML with custom scheme
            guard let htmlURL = URL(string: "\(customScheme)://\(htmlName).html") else {
                print("❌ [BarkWebVC] Failed to create URL for scheme: \(customScheme), page: \(htmlName)")
                return
            }
            webView.load(URLRequest(url: htmlURL))
            print("✅ [BarkWebVC] Loaded HTML with manifest: \(htmlName).html")

        } catch {
            print("❌ [BarkWebVC] Failed to load manifest: \(error)")
        }
    }

    /// Load an HTML file from a custom URL with resource mapping
    /// - Parameter customURL: The custom:// URL to load
    public func loadCustomURL(_ customURL: URL) {
        // Ensure view is loaded
        _ = view

        guard customURL.scheme == customScheme else {
            print("❌ [BarkWebVC] Invalid custom scheme: \(customURL.scheme ?? "nil")")
            return
        }

        webView.load(URLRequest(url: customURL))
        print("✅ [BarkWebVC] Loading custom URL: \(customURL)")
    }

    /// Register a resource manifest for a specific page
    /// - Parameters:
    ///   - pageName: The page name (e.g., "test_page")
    ///   - manifest: Dictionary mapping relative paths to network URLs
    public func registerResourceManifest(forPage pageName: String, manifest: [String: String]) {
        if let handler = webView.configuration.urlSchemeHandler(forURLScheme: customScheme) as? ManifestURLSchemeHandler {
            handler.registerManifest(forPage: pageName, manifest: manifest)
            print("✅ [BarkWebVC] Registered manifest for page: \(pageName)")
        } else {
            print("❌ [BarkWebVC] ManifestURLSchemeHandler not available")
        }
    }

    /// Clear cached resources for a specific page
    /// - Parameter pageName: The page name to clear cache for
    public func clearResourceCache(forPage pageName: String) {
        if let handler = webView.configuration.urlSchemeHandler(forURLScheme: customScheme) as? ManifestURLSchemeHandler {
            handler.unregisterManifest(forPage: pageName)
            print("✅ [BarkWebVC] Cleared cache for page: \(pageName)")
        }
    }
}
