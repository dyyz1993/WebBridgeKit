//
//  WebBrowserViewController+Navigation.swift
//  WebBridgeKit
//
//  WKNavigationDelegate, URL loading, cache support, debug mode
//

import WebKit

// MARK: - WKNavigationDelegate - Auto-Capture by Rules

extension WebBrowserViewController: WKNavigationDelegate {

    /// 处理导航策略，防止系统弹窗和外部跳转
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if !["http", "https", "file", "about", "manifest-cache"].contains(scheme) {
            print("🔗 [Browser] 拦截到特殊协议跳转: \(url.absoluteString)")
        }

        decisionHandler(.allow)
    }

    /// 页面加载完成 - 检查是否需要自动缓存页面
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        print("📄 ========================================")
        print("📄 页面加载完成")
        print("- URL: \(url.absoluteString)")
        print("- Title: \(webView.title ?? "nil")")
        print("📄 ========================================")
        WebBridgeLogger.shared.info("📄 Page loaded: \(url.absoluteString)")

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

                    print("✅ History updated successfully for: \(url.absoluteString)")
                } catch {
                    WebBridgeLogger.shared.log(.error, "Failed to update history: \(error.localizedDescription)")
                    print("❌ Failed to update history for \(url.absoluteString): \(error.localizedDescription)")
                }
            }
        }

        let (shouldCache, matchedRule) = PageCacheRuleManager.shared.shouldCache(url: url)

        print("🔍 缓存检查结果:")
        print("- shouldCache: \(shouldCache)")
        print("- matchedRule: \(matchedRule?.name ?? "nil")")
        print("🔍 ========================================")
        WebBridgeLogger.shared.info("🔍 Cache check - shouldCache: \(shouldCache), matchedRule: \(matchedRule?.name ?? "nil")")

        if shouldCache, let rule = matchedRule {
            print("🎯 触发自动缓存，规则: \(rule.name)")
            WebBridgeLogger.shared.info("🎯 URL '\(url.absoluteString)' matches page cache rule: \(rule.name)")

            autoCachePage(url: url, rule: rule)
        }
    }

    /// 自动缓存 URL 对应的页面及所有资源
    private func autoCachePage(url: URL, rule: PageCacheRule) {
        print("🎯 ========================================")
        print("🎯 开始自动缓存页面")
        print("- URL: \(url.absoluteString)")
        print("- 规则: \(rule.name)")
        print("🎯 ========================================")

        WebPageOfflineCacheManager.shared.cachePage(
            url: url,
            rule: rule
        ) { progress in
            print("📊 [\(rule.name)] 缓存进度: \(Int(progress * 100))%")
            WebBridgeLogger.shared.info("Caching progress: \(progress * 100)%")
        } completion: { result in
            switch result {
            case .success(let pageInfo):
                print("✅ ========================================")
                print("✅ 自动缓存成功！")
                print("- URL: \(url.absoluteString)")
                print("- 规则: \(rule.name)")
                print("- 标题: \(pageInfo.title)")
                print("- 资源数: \(pageInfo.resourceCount)")
                print("- 大小: \(pageInfo.formattedSize)")
                print("✅ ========================================")
                WebBridgeLogger.shared.info("""
                ✅ Page cached by rule '\(rule.name)':
                - URL: \(url.absoluteString)
                - Title: \(pageInfo.title)
                - Resources: \(pageInfo.resourceCount)
                - Size: \(pageInfo.formattedSize)
                - Cached at: \(pageInfo.formattedCachedAt)
                """)

            case .failure(let error):
                print("❌ ========================================")
                print("❌ 自动缓存失败！")
                print("- URL: \(url.absoluteString)")
                print("- 错误: \(error.localizedDescription)")
                print("❌ ========================================")
                WebBridgeLogger.shared.error("❌ Failed to cache page: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cache Support

    /// 使用 Manifest 缓存加载 URL
    public func loadURLWithCache(_ url: URL, forceRefresh: Bool = false) {
        print("🌐 [WebBrowserVC] Loading URL with cache: \(url.absoluteString)")

        currentURL = url

        injectDebugScript(for: url)

        updateCacheStatus(source: "CHECKING")

        print("🔍 [WebBridgeVC] loadURLWithCache 调用，debugMode=\(debugMode)")
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
                    print("✅ [WebBrowserVC] URL loaded with cache: \(url.absoluteString)")
                    if self.currentCacheSource == "CHECKING" || self.currentCacheSource == "LIVE" {
                        let isActuallyCached = self.checkIfActuallyCached(for: url)
                        if !isActuallyCached {
                            self.updateCacheStatus(source: "LIVE")
                        }
                    }
                case .failure(let error):
                    print("❌ [WebBrowserVC] Failed to load URL: \(error.localizedDescription)")
                    self.updateCacheStatus(source: "LIVE")

                    let isCustomScheme = url.scheme == "custom" || url.scheme == "wb-resource"
                    if isCustomScheme {
                        self.loadErrorPage(url: url, error: error)
                    } else {
                        if url.isFileURL {
                            self.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                        } else {
                            let request = URLRequest(url: url)
                            self.webView.load(request)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Debug Mode

    /// 注入调试脚本（当 debugMode 启用时）
    private func injectDebugScript(for url: URL) {
        print("🔍 [WebBridgeVC] injectDebugScript 被调用！debugMode=\(debugMode)")
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
                        <strong>🔍 WebBridge 调试模式</strong>
                        <button onclick="navigator.clipboard.writeText('URL: \\(url.absoluteString)\\n错误: 页面加载失败')" style="float:right;background:#4CAF50;color:white;border:none;padding:4px 8px;border-radius:4px;cursor:pointer;">复制信息</button>
                    </div>
                    <div style="padding:15px;">
                        <div style="color:#ffc107;margin-bottom:10px;">⚠️ 检测到白屏</div>
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
        print("🔍 [WebBridgeVC] Debug script injected for: \(url.absoluteString)")
    }

    /// 加载错误提示页面
    public func loadErrorPage(url: URL, error: Error) {
        let errorHTML = generateErrorHTML(url: url, error: error)
        webView.loadHTMLString(errorHTML, baseURL: url)
        print("⚠️ [WebBrowserVC] Loaded error page for: \(url.absoluteString)")
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
                <h1><span class="icon">🚫</span>WebBridge 资源加载失败</h1>
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

            print("📱 [Browser] Cache Status Updated: \(source)")
        }
    }

    /// 检查是否真正使用了缓存
    private func checkIfActuallyCached(for url: URL) -> Bool {
        NSLog("🔍 [Browser] Checking cache for URL: %@", url.absoluteString)

        if PersistentManifestLoader.shared.isCached(url: url) {
            NSLog("✅ [Browser] Cache Hit: Persistent (MANIFEST)")
            updateCacheStatus(source: "MANIFEST")
            return true
        }

        let appID = AppIDResolver.resolveAppID(from: url)
        NSLog("🔍 [Browser] Resolved AppID: %@", appID)

        if let manifest = ManifestCacheManager.shared.getCachedManifest(for: appID) {
            NSLog("✅ [Browser] Cache Hit: Lazy Manifest (INTERCEPT), persistent=%d", manifest.persistent ?? false)
            updateCacheStatus(source: "INTERCEPT")
            return true
        }

        NSLog("❌ [Browser] Cache Miss")
        return false
    }
}
