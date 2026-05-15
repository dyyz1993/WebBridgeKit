//
//  ManifestCacheDemo.swift
//  SuperApp
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebKit
import WebBridgeKit

/// Manifest Cache System Demo
/// Demonstrates how to use the manifest-based caching system with custom:// URL scheme
class ManifestCacheDemo: UIViewController {

    // MARK: - Properties

    private var webView: WKWebView!
    private var manifestManager: ManifestCacheManager!
    private var urlSchemeHandler: ManifestURLSchemeHandler!

    private let pageKey = "manifest_cache_demo"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Manifest Cache Demo"
        view.backgroundColor = ThemeColors.current.background

        setupWebView()
        setupManifest()
        loadDemoPage()

        // Add refresh button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshDemo)
        )

        // Add stats button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Stats",
            style: .plain,
            target: self,
            action: #selector(showCacheStats)
        )
    }

    // MARK: - Setup

    private func setupWebView() {
        print("📱 [Demo] Setting up WebView with Manifest Cache")

        // Create WKWebViewConfiguration
        let configuration = WKWebViewConfiguration()

        // Register the custom URL scheme handler
        ManifestURLSchemeHandler.register(to: configuration, scheme: "custom")

        // Create WebView
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        print("✅ [Demo] WebView created with custom:// URL scheme")
    }

    private func setupManifest() {
        print("📋 [Demo] Setting up manifest cache")

        manifestManager = ManifestCacheManager.shared

        // Create a manifest with resource mappings
        // These map relative paths (like "logo.png") to real network URLs
        let manifest = Manifest(
            resources: [
                // Images - using reliable placeholder services
                "logo.png": "https://via.placeholder.com/150x150/667eea/ffffff?text=Logo",
                "test-image.jpg": "https://via.placeholder.com/300x200/764ba2/ffffff?text=Test+Image",

                // CSS - using CDN resources
                "styles.css": "https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css",

                // JavaScript - using CDN resources
                "app.js": "https://code.jquery.com/jquery-3.6.0.min.js"
            ],
            version: "1.0.0",
            lastUpdated: Date()
        )

        // Save the manifest for this page
        manifestManager.savePage(
            pageKey: pageKey,
            html: loadDemoHTML(),
            manifest: manifest
        )

        print("✅ [Demo] Manifest saved with \(manifest.resources.count) resource mappings")
        print("   Mappings:")
        for (relativePath, url) in manifest.resources {
            print("   - \(relativePath) -> \(url)")
        }
    }

    private func loadDemoPage() {
        print("🚀 [Demo] Loading demo page")

        // Load the page using manifest cache
        // This will use loadHTMLString with baseURL = "custom://"
        // Relative paths will auto-complete to custom:// URLs
        manifestManager.loadPage(pageKey: pageKey, into: webView)

        print("✅ [Demo] Page loaded with custom:// baseURL")
        print("   Relative paths will resolve to custom:// URLs")
        print("   Example: src='logo.png' -> custom://logo.png")
    }

    // MARK: - Demo HTML

    private func loadDemoHTML() -> String {
        // Try to load from test_resources directory
        if let path = Bundle.main.path(forResource: "manifest_cache_test", ofType: "html", inDirectory: "test_resources") {
            do {
                let html = try String(contentsOfFile: path, encoding: .utf8)
                print("✅ [Demo] Loaded HTML from test_resources/manifest_cache_test.html")
                return html
            } catch {
                print("⚠️ [Demo] Could not load HTML from test_resources: \(error)")
            }
        }

        // Try to load from main bundle
        if let path = Bundle.main.path(forResource: "manifest_cache_test", ofType: "html") {
            do {
                let html = try String(contentsOfFile: path, encoding: .utf8)
                print("✅ [Demo] Loaded HTML from main bundle")
                return html
            } catch {
                print("⚠️ [Demo] Could not load HTML from bundle: \(error)")
            }
        }

        // Fallback: Use simple inline HTML
        print("⚠️ [Demo] Using fallback inline HTML")
        return getFallbackHTML()
    }

    private func getFallbackHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Manifest Cache Demo</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                }
                .container {
                    background: white;
                    border-radius: 12px;
                    padding: 30px;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
                }
                h1 { color: #333; margin-bottom: 10px; }
                .subtitle { color: #666; margin-bottom: 20px; }
                .info {
                    background: #f0f7ff;
                    border-left: 4px solid #2196F3;
                    padding: 15px;
                    margin: 20px 0;
                    border-radius: 4px;
                }
                .success {
                    background: #e8f5e9;
                    border-left-color: #4CAF50;
                }
                .success h3 { color: #4CAF50; }
                img { max-width: 100%; border-radius: 8px; margin: 10px 0; }
                code {
                    background: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: monospace;
                    color: #e91e63;
                }
                .test-item {
                    padding: 15px;
                    margin: 10px 0;
                    background: #f9f9f9;
                    border-radius: 8px;
                    border-left: 4px solid #ddd;
                }
                .test-item.success { border-left-color: #4CAF50; }
                .test-item.error { border-left-color: #f44336; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🚀 Manifest Cache Demo</h1>
                <p class="subtitle">验证基于 Manifest 的资源缓存机制</p>

                <div class="info success">
                    <h3>✅ Success!</h3>
                    <p>此页面使用 <strong>manifest cache system</strong> 和 <code>custom://</code> URL scheme 加载。</p>
                    <p>相对路径如 <code>src="logo.png"</code> 会自动解析为 <code>custom://logo.png</code> 并被 URL scheme handler 拦截！</p>
                </div>

                <h2>🧪 资源加载测试</h2>

                <div class="test-item" id="test-logo">
                    <strong>📷 图片测试</strong><br>
                    路径: <code>logo.png</code> → <code>custom://logo.png</code><br>
                    真实 URL: https://via.placeholder.com/150<br>
                    <img src="logo.png" alt="Demo Logo"
                         onload="document.getElementById('test-logo').classList.add('success');"
                         onerror="document.getElementById('test-logo').classList.add('error');">
                </div>

                <div class="test-item" id="test-css">
                    <strong>🎨 CSS 测试</strong><br>
                    路径: <code>styles.css</code> → <code>custom://styles.css</code><br>
                    真实 URL: https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css<br>
                    <link rel="stylesheet" href="styles.css"
                          onload="document.getElementById('test-css').classList.add('success');"
                          onerror="document.getElementById('test-css').classList.add('error');">
                </div>

                <div class="test-item" id="test-js">
                    <strong>📜 JavaScript 测试</strong><br>
                    路径: <code>app.js</code> → <code>custom://app.js</code><br>
                    真实 URL: https://code.jquery.com/jquery-3.6.0.min.js<br>
                    <script src="app.js"
                            onload="document.getElementById('test-js').classList.add('success');"
                            onerror="document.getElementById('test-js').classList.add('error');"></script>
                </div>

                <h2>📋 工作流程</h2>
                <ol>
                    <li>HTML 使用相对路径: <code>&lt;img src="logo.png"&gt;</code></li>
                    <li>baseURL 设置为 <code>custom://</code></li>
                    <li>相对路径自动补全: <code>logo.png</code> → <code>custom://logo.png</code></li>
                    <li>WKURLSchemeHandler 拦截 <code>custom://</code> 请求</li>
                    <li>Handler 在 manifest.json 中查找真实 URL</li>
                    <li>下载资源并缓存以备将来使用</li>
                </ol>

                <div class="info">
                    <h3>💡 提示</h3>
                    <p>点击右上角的 "Stats" 按钮查看缓存统计信息。</p>
                    <p>点击 "刷新" 按钮重新加载页面（第二次加载应该命中缓存）。</p>
                </div>
            </div>

            <script>
                console.log('✅ JavaScript loaded successfully');
                console.log('📊 Page working with custom:// URL scheme');
                document.addEventListener('DOMContentLoaded', () => {
                    console.log('🎯 DOM fully loaded');
                });
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Actions

    @objc private func refreshDemo() {
        print("🔄 [Demo] Refreshing demo page")
        loadDemoPage()

        // Show alert after refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            let alert = UIAlertController(
                title: "页面已刷新",
                message: "查看控制台日志以了解资源是否从缓存加载。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    @objc private func showCacheStats() {
        let stats = manifestManager.getStats()

        let message = """
        总请求数: \(stats.totalRequests)
        缓存命中: \(stats.cacheHits)
        缓存未命中: \(stats.cacheMisses)
        命中率: \(stats.formattedHitRate)
        缓存大小: \(stats.formattedCacheSize)
        """

        let alert = UIAlertController(
            title: "📊 缓存统计",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "确定", style: .default))

        alert.addAction(UIAlertAction(title: "清除缓存", style: .destructive) { [weak self] _ in
            self?.clearCache()
        })

        present(alert, animated: true)
    }

    private func clearCache() {
        manifestManager.clearPage(pageKey: pageKey)

        let alert = UIAlertController(
            title: "缓存已清除",
            message: "此页面的 manifest 缓存已清除。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            // Reload the page
            self?.loadDemoPage()
        })

        present(alert, animated: true)
    }
}

// MARK: - Usage Example Extension

extension ManifestCacheDemo {

    /// Example: How to use the manifest cache system in your app
    static func demonstrateUsage() {
        print("📚 [Usage Guide] Manifest Cache System")
        print("=====================================")
        print("")
        print("1. 注册 URL Scheme Handler:")
        print("   let configuration = WKWebViewConfiguration()")
        print("   ManifestURLSchemeHandler.register(to: configuration, scheme: \"custom\")")
        print("")
        print("2. 创建 Manifest:")
        print("   let manifest = Manifest(resources: [")
        print("       \"logo.png\": \"https://wbk.shanbox.19930810.xyz:8443/logo.png\",")
        print("       \"styles.css\": \"https://wbk.shanbox.19930810.xyz:8443/styles.css\"")
        print("   ])")
        print("")
        print("3. 保存页面及 Manifest:")
        print("   ManifestCacheManager.shared.savePage(")
        print("       pageKey: \"my-page\",")
        print("       html: htmlString,")
        print("       manifest: manifest")
        print("   )")
        print("")
        print("4. 加载页面:")
        print("   ManifestCacheManager.shared.loadPage(")
        print("       pageKey: \"my-page\",")
        print("       into: webView")
        print("   )")
        print("")
        print("5. 查看统计:")
        print("   let stats = ManifestCacheManager.shared.getStats()")
        print("   print(\"Hit rate: \\(stats.formattedHitRate)\")")
        print("")
        print("✅ 就这样！系统会处理其余部分。")
    }
}
