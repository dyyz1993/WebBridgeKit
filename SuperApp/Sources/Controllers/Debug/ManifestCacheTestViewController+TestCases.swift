//
//  ManifestCacheTestViewController+TestCases.swift
//  SuperApp
//
//  Test methods extracted from ManifestCacheTestViewController.
//

import UIKit
import SnapKit
import WebKit
import WebBridgeKit

extension ManifestCacheTestViewController {

    // MARK: - Test Methods

    /// 测试持久化加载
    private func testPersistentLoad(url: URL) {
        addLog("📥 持久化模式：")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // 首先检查是否已有缓存
        let isCached = PersistentManifestLoader.shared.isCached(url: url)
        if isCached {
            addLog("💡 检测到已有缓存，直接从缓存加载")
            addLog("   1. 读取缓存文件")
            addLog("   2. 加载到 WebView")

            PersistentManifestLoader.shared.loadFromCache(
                url: url,
                in: tempWebView
            ) { [weak self] result in
                // ✅ FIX: 回调可能在后台线程，必须切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.isTestRunning = false
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("开始测试", for: .normal)

                    switch result {
                    case .success:
                        self.addLog("✅ 从缓存加载成功")
                        self.updateStats()

                    case .failure(let error):
                        self.addLog("❌ 缓存加载失败: \(error.localizedDescription)")
                        // 如果缓存加载失败，尝试重新下载
                        self.addLog("⚠️ 缓存加载失败，尝试重新下载...")
                        self.downloadAndCache(url: url)
                    }
                }
            }
        } else {
            addLog("📥 首次加载，将下载所有资源：")
            addLog("   1. 下载 manifest.json")
            addLog("   2. 检查 persistent 字段")
            addLog("   3. 下载所有资源")
            addLog("   4. 加载到 WebView")
            downloadAndCache(url: url)
        }
    }

    /// 下载并缓存
    private func downloadAndCache(url: URL) {
        addLog("📥 持久化模式：显示全屏进度条")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // 创建全屏进度控制器
        let progressVC = FullScreenProgressViewController()
        progressVC.modalPresentationStyle = .fullScreen
        present(progressVC, animated: true) { [weak self] in
            guard let self = self else { return }

            // 进度条显示后再开始加载
            PersistentManifestLoader.load(
                url: url,
                in: tempWebView,
                from: self
            ) { [weak self, weak progressVC] result in
                // ✅ FIX: URLSession 回调在后台线程，必须切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.isTestRunning = false
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("开始测试", for: .normal)

                    // 关闭进度条
                    progressVC?.dismissWithAnimation { [weak self] in
                        guard let self = self else { return }

                        switch result {
                        case .success:
                            self.addLog("✅ 持久化加载成功")
                            self.updateStats()

                            // 打开全屏 WebView 展示页面
                            let displayVC = WebViewDisplayViewController(webView: tempWebView) {
                                self.dismiss(animated: true)
                            }
                            displayVC.modalPresentationStyle = .fullScreen
                            self.present(displayVC, animated: true)

                        case .failure(let error):
                            self.addLog("❌ 持久化加载失败!")
                            self.addLog("   错误类型: \(type(of: error))")
                            self.addLog("   错误描述: \(error.localizedDescription)")
                            self.addLog("   完整错误: \(error)")

                            // 检查是否是 URLError
                            if let urlError = error as? URLError {
                                self.addLog("   URLError 代码: \(urlError.code.rawValue)")
                                self.addLog("   URLError 描述: \(urlError.localizedDescription)")
                                if let failURL = urlError.failureURLString {
                                    self.addLog("   失败的 URL: \(failURL)")
                                }
                            }

                            // 检查是否是 LoaderError
                            if let loaderError = error as? PersistentManifestLoader.LoaderError {
                                self.addLog("   LoaderError: \(loaderError)")
                            }

                            // 检查缓存目录状态
                            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("WebBridgeKit/PersistentCache")
                            self.addLog("   缓存目录存在: \(FileManager.default.fileExists(atPath: cacheDir.path))")

                            self.showAlert(title: "测试失败", message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    /// 测试懒加载
    private func testLazyLoad(url: URL) {
        addLog("⚡ 懒加载模式：立即打开全屏页面")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // 创建新的全屏页面展示器
        let displayVC = WebViewDisplayViewController(webView: tempWebView) { [weak self] in
            self?.addLog("✅ 全屏页面已关闭")
            self?.dismiss(animated: true)
        }

        displayVC.modalPresentationStyle = .fullScreen
        addLog("📱 准备打开全屏页面...")

        // Delay presentation to next run loop to ensure UI is ready
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("🔍 [DEBUG] navigationController = \(String(describing: self.navigationController))")
            print("🔍 [DEBUG] tabBarController = \(String(describing: self.tabBarController))")
            print("🔍 [DEBUG] presentingViewController = \(String(describing: self.presentingViewController))")
            print("🔍 [DEBUG] view.window = \(String(describing: self.view.window))")
            print("🔍 [DEBUG] isViewLoaded = \(self.isViewLoaded)")

            // Try push instead of present for better reliability
            if let navController = self.navigationController {
                self.addLog("🔄 使用 Navigation Push 打开全屏页面")
                navController.pushViewController(displayVC, animated: true)
                self.addLog("✅ 全屏页面已打开")
            } else {
                // Fallback to present
                let presentingVC = self
                presentingVC.present(displayVC, animated: true) {
                    self.addLog("✅ 全屏页面已打开")
                }
            }
        }

        addLog("   1. 下载 manifest.json")
        addLog("   2. 立即加载 HTML")
        addLog("   3. 后台下载资源")

        // 后台加载
        LazyManifestLoader.load(
            url: url,
            in: tempWebView
        ) { [weak self] result in
            // ✅ FIX: URLSession 回调在后台线程，必须切换到主线程更新 UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.isTestRunning = false
                self.startButton.isEnabled = true
                self.startButton.setTitle("开始测试", for: .normal)

                switch result {
                case .success:
                    self.addLog("✅ 懒加载启动成功")
                    self.addLog("🔄 资源正在后台下载中...")
                    self.updateStats()

                    // 监控后台下载进度
                    self.monitorBackgroundDownload(url: url)

                case .failure(let error):
                    self.addLog("❌ 懒加载失败: \(error.localizedDescription)")
                    // 关闭全屏页面并显示错误
                    displayVC.dismiss(animated: true) {
                        self.showAlert(title: "测试失败", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    /// 测试智能加载（根据 manifest.persistent 自动选择模式）
    func testSmartLoad(url: URL) {
        addLog("🤖 智能模式：自动根据 manifest.json 的 persistent 字段选择加载器")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // ✅ 先创建 WebView 展示页面（先 present，这样进度页面可以覆盖在上面）
        addLog("📱 准备 WebView 展示页面...")
        let displayVC = WebViewDisplayViewController(webView: tempWebView) { [weak self] in
            self?.addLog("✅ 全屏页面已关闭")
            // 只关闭 WebView 展示页面，不要关闭测试页面
        }
        displayVC.modalPresentationStyle = .fullScreen

        // 先 present 展示页面
        present(displayVC, animated: true) { [weak self] in
            guard let self = self else { return }

            self.addLog("✅ WebView 展示页面已打开")

            // 然后在展示页面上调用 smartLoad
            // 如果是持久化模式，进度页面会覆盖在展示页面上
            // 下载完成后，进度页面关闭，WebView 就显示出来了
            self.addLog("📥 正在检查 manifest.json...")

            LazyManifestLoader.smartLoad(
                url: url,
                in: tempWebView,
                from: displayVC  // ✅ 从展示页面上显示进度页面
            ) { [weak self] result in
                // ✅ FIX: URLSession 回调在后台线程，必须切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.isTestRunning = false
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("开始测试", for: .normal)

                    switch result {
                    case .success:
                        // ✅ 展示页面已经打开了，不需要再 present
                        // 进度页面会自动关闭，WebView 就显示出来了
                        self.addLog("✅ 智能加载成功")
                        self.addLog("📱 WebView 已准备就绪")
                        self.updateStats()

                    case .failure(let error):
                        self.addLog("❌ 智能加载失败: \(error.localizedDescription)")

                        // 加载失败，关闭展示页面
                        displayVC.dismiss(animated: true) {
                            // 检查是否是持久化模式错误
                            if error.localizedDescription.contains("persistentModeDisabled") {
                                self.addLog("⚠️ manifest.json 的 persistent 字段为 false")
                                self.addLog("💡 建议：在 manifest.json 中设置 \"persistent\": true 以使用持久化模式")
                            }

                            self.showAlert(title: "测试失败", message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    /// 监控后台下载进度
    private func monitorBackgroundDownload(url: URL) {
        // ⚠️ 禁用进度监控（可能导致后台线程 UI 更新问题）
        // 懒加载会在后台自动下载，无需轮询
        /*
         let cacheID = "lazy_\(abs(url.absoluteString.hashValue))"

         // 定时检查进度
         Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
         guard let self = self else {
         timer.invalidate()
         return
         }

         if let state = LazyManifestLoader.shared.getLoadingState(for: url) {
         let progress = Int(state.progress * 100)
         self.addLog("⬇️ 下载进度: \(progress)% (\(state.downloadedResources)/\(state.totalResources))")

         if state.isCompleted {
         self.addLog("✅ 后台下载完成")
         self.updateStats()
         timer.invalidate()
         }
         } else {
         // 状态不存在，可能已完成或失败
         timer.invalidate()
         }
         }
         */
    }

}
