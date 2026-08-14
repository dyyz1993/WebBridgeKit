//
//  WebBrowserViewController+Navigation.swift
//  WebBridgeKit
//
//  WKNavigationDelegate, URL loading, cache support, debug mode
//

import WebKit
import os.log

// MARK: - WKNavigationDelegate - Auto-Capture by Rules
extension WebBrowserViewController: WKNavigationDelegate {

    /// 处理导航策略，防止系统弹窗和外部跳转
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationPolicy(for: navigationAction, in: webView))
    }

    @available(iOS 13.0, *)
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        preferences.allowsContentJavaScript = true
        decisionHandler(navigationPolicy(for: navigationAction, in: webView), preferences)
    }

    private func navigationPolicy(for navigationAction: WKNavigationAction, in webView: WKWebView) -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else {
            return .allow
        }

        //  Security: Block dangerous URL schemes
        let allowedSchemes: Set<String> = ["http", "https", "file", "about", "manifest-cache", "custom"]
        let blockedSchemes: Set<String> = ["javascript", "data", "vbscript"]

        if let scheme = url.scheme?.lowercased() {
            if blockedSchemes.contains(scheme) {
                Log.error("Blocked dangerous URL scheme: \(scheme) - \(url.absoluteString)", category: .general)
                StructuredLogger.shared.error("Blocked dangerous URL scheme: \(scheme) - \(url.absoluteString)", category: .navigation)
                return .cancel
            }

            if !allowedSchemes.contains(scheme) {
                Log.warning("Blocked unknown URL scheme: \(scheme) - \(url.absoluteString)", category: .general)
                StructuredLogger.shared.warning("Blocked unknown URL scheme: \(scheme) - \(url.absoluteString)", category: .navigation)
                return .cancel
            }
        }

        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            return .cancel
        }

        StructuredLogger.shared.debug("Allowed navigation: \(url.absoluteString)", category: .navigation)
        return .allow
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           let contentType = response.allHeaderFields["Content-Type"] as? String,
           contentType.contains("application/json") {
            decisionHandler(.cancel)
            DispatchQueue.main.async { [weak self] in
                self?.handleJSONResponse(response, url: response.url)
            }
            return
        }
        decisionHandler(.allow)
    }

    private func handleJSONResponse(_ response: HTTPURLResponse, url: URL?) {
        guard let url = url else { return }
        let statusCode = response.statusCode
        let alert = UIAlertController(
            title: "API Response",
            message: "\(url.absoluteString)\n\nHTTP \(statusCode)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// 页面加载完成 - 检查是否需要自动缓存页面
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        HUDService.shared.dismiss()

        guard let url = webView.url else { return }

        guard let start = loadStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        Log.info("WebView first screen load: \(String(format: "%.3f", duration))s (url: \(url.absoluteString))", category: .performance)
        loadStartTime = nil

        StructuredLogger.shared.info("Page loaded - URL: \(url.absoluteString), Title: \(webView.title ?? "nil"), Load time: \(String(format: "%.3f", duration))s", category: .navigation)
        WebBridgeLogger.shared.info("[DOC] Page loaded: \(url.absoluteString)")

        checkURLParameters(url)

        fetchFavicon { [weak self] faviconData in
            guard let self = self else { return }

            Task { @MainActor in
                do {
                    try await WebPageHistoryManager.shared.addOrUpdateHistory(
                        url: url,
                        title: self.webView.title,
                        favicon: faviconData
                    )

                    NotificationCenter.default.post(name: .historyDidUpdate, object: nil)

                    StructuredLogger.shared.debug("History updated for: \(url.absoluteString)", category: .storage)
                } catch {
                    WebBridgeLogger.shared.log(.error, "Failed to update history: \(error.localizedDescription)")
                    StructuredLogger.shared.error("Failed to update history for \(url.absoluteString): \(error.localizedDescription)", category: .storage)
                }
            }
        }

        let (shouldCache, matchedRule) = PageCacheRuleManager.shared.shouldCache(url: url)

        StructuredLogger.shared.debug("Cache check - shouldCache: \(shouldCache), matchedRule: \(matchedRule?.name ?? "nil")", category: .cache)
        WebBridgeLogger.shared.info("[SEARCH] Cache check - shouldCache: \(shouldCache), matchedRule: \(matchedRule?.name ?? "nil")")

        if shouldCache, let rule = matchedRule {
            StructuredLogger.shared.debug("Triggered auto-cache with rule: \(rule.name)", category: .cache)
            WebBridgeLogger.shared.info("[TARGET] URL '\(url.absoluteString)' matches page cache rule: \(rule.name)")

            autoCachePage(url: url, rule: rule)
        }
    }

    /// 自动缓存 URL 对应的页面及所有资源
    private func autoCachePage(url: URL, rule: PageCacheRule) {
        StructuredLogger.shared.info("Auto-caching page - URL: \(url.absoluteString), Rule: \(rule.name)", category: .cache)

        WebPageOfflineCacheManager.shared.cachePage(
            url: url,
            rule: rule
        ) { progress in
            StructuredLogger.shared.debug("Caching progress [\(rule.name)]: \(Int(progress * 100))%", category: .cache)
            WebBridgeLogger.shared.info("Caching progress: \(progress * 100)%")
        } completion: { result in
            switch result {
            case .success(let pageInfo):
                StructuredLogger.shared.info("Auto-cache success - URL: \(url.absoluteString), Rule: \(rule.name), Title: \(pageInfo.title), Resources: \(pageInfo.resourceCount), Size: \(pageInfo.formattedSize)", category: .cache)
                WebBridgeLogger.shared.info("""
                [OK] Page cached by rule '\(rule.name)':
                - URL: \(url.absoluteString)
                - Title: \(pageInfo.title)
                - Resources: \(pageInfo.resourceCount)
                - Size: \(pageInfo.formattedSize)
                - Cached at: \(pageInfo.formattedCachedAt)
                """)

            case .failure(let error):
                StructuredLogger.shared.error("Auto-cache failed - URL: \(url.absoluteString), Error: \(error.localizedDescription)", category: .cache)
                WebBridgeLogger.shared.error("[FAIL] Failed to cache page: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cache Support

    /// Load a standard PWA without probing WebBridgeKit's resource manifest.
    /// WKWebsiteDataStore.default() still persists cookies, localStorage,
    /// IndexedDB, Cache Storage, and service-worker state.
    public func loadURLDirect(_ url: URL, forceRefresh: Bool = false) {
        performDirectLoad(url, forceRefresh: forceRefresh)
    }

    func performDirectLoad(_ url: URL, forceRefresh: Bool) {
        os_log("Starting standard PWA navigation", log: OSLog.default, type: .info)
        currentURL = url
        loadStartTime = Date()
        injectDebugScript(for: url)
        updateCacheStatus(source: "LIVE")

        let policy: URLRequest.CachePolicy = forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        webView.load(URLRequest(url: url, cachePolicy: policy, timeoutInterval: 30))
        StructuredLogger.shared.info("Loading standard PWA directly: \(url.absoluteString)", category: .navigation)
    }

    /// 使用 Manifest 缓存加载 URL
    public func loadURLWithCache(_ url: URL, forceRefresh: Bool = false) {
        guard hasAppeared, isViewLoaded, isViewModelBinded else {
            currentURL = url
            pendingCacheLoad = (url, forceRefresh)
            StructuredLogger.shared.debug("Deferring URL load until view appears: \(url.absoluteString)", category: .navigation)
            return
        }

        performLoadURLWithCache(url, forceRefresh: forceRefresh)
    }

    func performLoadURLWithCache(_ url: URL, forceRefresh: Bool = false) {
        StructuredLogger.shared.debug("Loading URL with cache: \(url.absoluteString)", category: .navigation)

        currentURL = url

        injectDebugScript(for: url)

        updateCacheStatus(source: "CHECKING")

        StructuredLogger.shared.debug("loadURLWithCache called, debugMode=\(debugMode)", category: .navigation)
        LazyManifestLoader.smartLoad(
            url: url,
            in: webView,
            from: self,
            forceRefresh: forceRefresh
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success:
                    StructuredLogger.shared.info("URL loaded with cache: \(url.absoluteString)", category: .navigation)
                    if self.currentCacheSource == "CHECKING" || self.currentCacheSource == "LIVE" {
                        let isActuallyCached = self.checkIfActuallyCached(for: url)
                        if !isActuallyCached {
                            self.updateCacheStatus(source: "LIVE")
                        }
                    }
                case .failure(let error):
                    StructuredLogger.shared.error("Failed to load URL: \(error.localizedDescription)", category: .navigation)
                    self.updateCacheStatus(source: "LIVE")
                    // smartLoad 已经在 error fallback 里调了 webView.load，不再重复加载
                }
            }
        }
    }

    // MARK: - Debug Mode

    /// 注入调试脚本（当 debugMode 启用时）
    private func injectDebugScript(for url: URL) {
        StructuredLogger.shared.debug("injectDebugScript called, debugMode=\(debugMode)", category: .navigation)
        guard debugMode else { return }

        let debugScript = """
        (function() {
            'use strict';

            const CONFIG = {
                checkInterval: 500,
                maxStackTrace: 10,
                verboseLogging: true
            };

            const state = {
                hasError: false,
                errorTimestamp: null,
                stackTrace: [],
                loadStartTime: Date.now()
            };

            function checkErrorState() {
                const title = document.title || '';
                const isBlank = title === '' || title === 'about:blank';

                if (isBlank && !state.hasError) {
                    state.hasError = true;
                    state.errorTimestamp = new Date().toISOString();
                    state.stackTrace.push({
                        message: '页面加载失败 - 白屏检测',
                        time: new Date().toISOString(),
                        type: 'error'
                    });
                    showErrorPanel();
                }
            }

            function showErrorPanel() {
                if (document.getElementById('wb-debug-panel')) return;

                const panel = document.createElement('div');
                panel.id = 'wb-debug-panel';
                panel.style.cssText = 'position:fixed;top:10px;right:10px;width:300px;max-height:80vh;background:rgba(220,53,69,0.95);border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,0.15);font-family:-apple-system,system-ui,sans-serif;font-size:12px;color:#fff;z-index:99999;overflow:hidden;';
                panel.innerHTML = `
                    <div style="padding:15px;border-bottom:1px solid rgba(255,255,255,255,0.1);">
                        <strong>[SEARCH] WebBridge 调试模式</strong>
                        <button onclick="navigator.clipboard.writeText('URL: \\(url.absoluteString)\\n错误: 页面加载失败')" style="float:right;background:#4CAF50;color:white;border:none;padding:4px 8px;border-radius:4px;cursor:pointer;">复制信息</button>
                    </div>
                    <div style="padding:15px;">
                        <div style="color:#ffc107;margin-bottom:10px;">[WARN] 检测到白屏</div>
                        <div style="font-size:11px;color:#ddd;">页面标题为空或 about:blank</div>
                    </div>
                `;
                document.body.appendChild(panel);
                console.log('%c[WebBridge Debug] 错误面板已显示', 'color: #f44336');
            }

            setInterval(checkErrorState, CONFIG.checkInterval);
            console.log('%c[WebBridge Debug] 调试模式已启用', 'color: #4CAF50');
            console.log('[WebBridge Debug] 监控 URL: \(url.absoluteString)');
        })();
        """

        let userScript = WKUserScript(
            source: debugScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        webView.configuration.userContentController.addUserScript(userScript)
        StructuredLogger.shared.debug("Debug script injected for: \(url.absoluteString)", category: .navigation)
    }

    /// 加载错误提示页面
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        os_log("PWA navigation failed: %{public}@/%{public}ld", log: OSLog.default, type: .error, nsError.domain, nsError.code)
        HUDService.shared.showError(withStatus: error.localizedDescription)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        os_log("PWA provisional navigation failed: %{public}@/%{public}ld", log: OSLog.default, type: .error, nsError.domain, nsError.code)
        HUDService.shared.showError(withStatus: error.localizedDescription)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("PWA provisional navigation started", log: OSLog.default, type: .info)
        loadStartTime = Date()
        HUDService.shared.show()
    }

    /// 加载错误提示页面
    public func loadErrorPage(url: URL, error: Error) {
        let errorHTML = generateErrorHTML(url: url, error: error)
        webView.loadHTMLString(errorHTML, baseURL: url)
        StructuredLogger.shared.warning("Loaded error page for: \(url.absoluteString)", category: .navigation)
    }

    /// 生成错误提示 HTML
    private func generateErrorHTML(url: URL, error: Error) -> String {
        let urlString = url.absoluteString
        let errorMessage = error.localizedDescription

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>WebBridge 资源加载失败</title>
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
                .btn { display: inline-block; background: #4a5568; color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none; margin-top: 15px; font-size: 14px; }
                .btn:hover { background: #2d3748; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1><span class="icon">[BLOCK]</span>WebBridge 资源加载失败</h1>
                <p>在处理缓存加载请求时遇到了错误，无法加载目标页面。</p>

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
                        <li>检查网络连接是否正常。</li>
                        <li>确认 <code>manifest.json</code> 映射表是否包含该相对路径。</li>
                        <li>如果是 <code>wb-resource://</code>，请确认持久化缓存目录中是否存在该文件。</li>
                        <li>尝试在管理页面清理缓存并重新加载。</li>
                    </ul>
                    <a href="javascript:location.reload()" class="btn">重试加载 (Reload)</a>
                </div>
            </div>
        </body>
        </html>
        """
    }

    /// 更新缓存状态显示
    func updateCacheStatus(source: String) {
        self.currentCacheSource = source

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.cacheStatusLabel.text = source

            switch source {
            case "LIVE":
                self.cacheStatusLabel.backgroundColor = ThemeTokens.Color.textSecondary.withAlphaComponent(0.6)
            case "INTERCEPT":
                self.cacheStatusLabel.backgroundColor = ThemeTokens.Color.success
            case "MANIFEST", "HTML":
                self.cacheStatusLabel.backgroundColor = ThemeTokens.Color.primary
            case "CHECKING":
                self.cacheStatusLabel.backgroundColor = ThemeTokens.Color.warning
            default:
                self.cacheStatusLabel.backgroundColor = ThemeTokens.Color.warning
            }

            StructuredLogger.shared.debug("Cache Status Updated: \(source)", category: .cache)
        }
    }

    /// 检查是否真正使用了缓存
    private func checkIfActuallyCached(for url: URL) -> Bool {
        NSLog("[SEARCH] [Browser] Checking cache for URL: %@", url.absoluteString)

        if PersistentManifestLoader.shared.isCached(url: url) {
            NSLog("[OK] [Browser] Cache Hit: Persistent (MANIFEST)")
            updateCacheStatus(source: "MANIFEST")
            return true
        }

        let appID = AppIDResolver.resolveAppID(from: url)
        NSLog("[SEARCH] [Browser] Resolved AppID: %@", appID)

        if let manifest = ManifestCacheManager.shared.getCachedManifest(for: appID) {
            NSLog("[OK] [Browser] Cache Hit: Lazy Manifest (INTERCEPT), persistent=%d", manifest.persistent ?? false)
            updateCacheStatus(source: "INTERCEPT")
            return true
        }

        NSLog("[FAIL] [Browser] Cache Miss")
        return false
    }
}
