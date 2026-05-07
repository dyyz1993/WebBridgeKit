//
//  WebBrowserViewController+Menu.swift
//  WebBridgeKit
//
//  Menu, bookmarks, debug info, cache stats, performance info, favicon
//

import UIKit

extension WebBrowserViewController {

    // MARK: - Menu

    func showMenu() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Browser Menu", comment: ""),
            message: nil,
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🔄 Refresh", comment: ""), style: .default) { [weak self] _ in
            self?.webView.reload()
        })

        let toggleTitle = hideNavBar ? "📌 显示导航栏" : "🎯 隐藏导航栏"
        alertController.addAction(UIAlertAction(title: NSLocalizedString(toggleTitle, comment: ""), style: .default) { [weak self] _ in
            self?.setNavigationBarHidden(!(self?.hideNavBar ?? false))
        })

        let statusBarToggleTitle = isStatusBarHidden ? "📊 显示状态栏" : "📱 隐藏状态栏"
        alertController.addAction(UIAlertAction(title: NSLocalizedString(statusBarToggleTitle, comment: ""), style: .default) { [weak self] _ in
            self?.setStatusBarHidden(!(self?.isStatusBarHidden ?? false))
        })

        if let url = webView.url {
            let favoriteService = ServiceLocator.favorite
            let isFavorited = favoriteService.findFavorite(url: url) != nil
            let favoriteTitle = isFavorited ? "⭐ 取消收藏" : "☆ 收藏页面"

            alertController.addAction(UIAlertAction(title: NSLocalizedString(favoriteTitle, comment: ""), style: .default) { [weak self] _ in
                guard let self = self else { return }
                if isFavorited {
                    favoriteService.deleteFavorite(url: url)
                } else {
                    self.fetchFavicon { data in
                        favoriteService.addFavorite(url: url, title: self.webView.title, favicon: data)
                    }
                }
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("📚 Bookmarks", comment: ""), style: .default) { [weak self] _ in
            self?.showBookmarks()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🌉 JS Bridge Test", comment: ""), style: .default) { [weak self] _ in
            self?.loadJSBridgeTestPage()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🎮 Voice Game", comment: ""), style: .default) { [weak self] _ in
            self?.loadGamePage()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🔐 Permissions", comment: ""), style: .default) { [weak self] _ in
            self?.loadPermissionsPage()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("💾 Cache Statistics", comment: ""), style: .default) { [weak self] _ in
            self?.showSystemCacheStatistics()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🗂️ Cache Debug", comment: ""), style: .default) { [weak self] _ in
            self?.showCacheDebugPanel()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("📊 Performance Info", comment: ""), style: .default) { [weak self] _ in
            self?.showPerformanceInfo()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🔍 Debug Info", comment: ""), style: .default) { [weak self] _ in
            self?.showDebugInfo()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("🏠 Welcome Page", comment: ""), style: .default) { [weak self] _ in
            self?.loadWelcomePage()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))

        present(alertController, animated: true)
    }

    private func showBookmarks() {
        let bookmarksVC = WebBookmarkViewController(viewModel: WebBookmarkViewModel())
        navigationController?.pushViewController(bookmarksVC, animated: true)
    }

    private func showSystemCacheStatistics() {
        WebCacheManager.shared.fetchSystemCacheStatistics()
            .subscribe(onNext: { stats in
                let message = stats.map { stat in
                    "\(stat.domain): \(ByteCountFormatter.string(fromByteCount: stat.totalSize, countStyle: .file))"
                }.joined(separator: "\n")

                let alert = UIAlertController(
                    title: NSLocalizedString("Cache Statistics", comment: ""),
                    message: message.isEmpty ? "No cache data" : message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                self.present(alert, animated: true)
            })
            .disposed(by: rx)
    }

    private func showCacheDebugPanel() {
        let debugPanel = WebCacheDebugPanelViewController()
        let navController = UINavigationController(rootViewController: debugPanel)
        present(navController, animated: true)
    }

    private func showPerformanceInfo() {
        guard let currentURL = webView.url else {
            let alert = UIAlertController(
                title: "Performance Info",
                message: "No page loaded",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let domain = currentURL.host ?? "unknown"
        let report = WebViewPerformanceMonitor.shared.generateReport()

        let alert = UIAlertController(
            title: "Performance Info (\(domain))",
            message: report,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showDebugInfo() {
        let info = [
            "📱 当前 URL": webView.url?.absoluteString ?? "None",
            "📄 页面标题": webView.title ?? "None",
            "⬅️ 可以后退": webView.canGoBack ? "是" : "否",
            "➡️ 可以前进": webView.canGoForward ? "是" : "否",
            "🔄 加载中": webView.isLoading ? "是" : "否",
            "📊 加载进度": String(format: "%.1f%%", webView.estimatedProgress * 100),
            "🎛️ 导航栏": hideNavBar ? "隐藏" : "显示",
            "📊 状态栏": isStatusBarHidden ? "隐藏" : "显示"
        ]

        let message = info.map { "\($0.key): \($0.value)" }.joined(separator: "\n")

        let alert = UIAlertController(
            title: "🔍 调试信息",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Favicon

    /// 获取页面图标
    func fetchFavicon(completion: @escaping (Data?) -> Void) {
        let script = """
        (function() {
            function getIcon(rel) {
                var links = document.getElementsByTagName('link');
                for (var i = 0; i < links.length; i++) {
                    var r = links[i].getAttribute('rel');
                    if (r && r.toLowerCase() === rel.toLowerCase()) {
                        return links[i].href;
                    }
                }
                return null;
            }

            var icon = getIcon('apple-touch-icon') ||
                       getIcon('icon') ||
                       getIcon('shortcut icon');

            if (icon) return icon;

            var links = document.getElementsByTagName('link');
            for (var i = 0; i < links.length; i++) {
                var r = links[i].getAttribute('rel');
                if (r && r.toLowerCase().indexOf('icon') !== -1) {
                    return links[i].href;
                }
            }

            return window.location.origin + '/favicon.ico';
        })()
        """

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self = self,
                  let urlString = result as? String,
                  let url = URL(string: urlString) else {
                completion(nil)
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0

            URLSession.shared.dataTask(with: request) { data, _, _ in
                DispatchQueue.main.async {
                    if let data = data, UIImage(data: data) != nil {
                        completion(data)
                    } else {
                        if !urlString.hasSuffix("/favicon.ico"),
                           let rootUrl = URL(string: "/favicon.ico", relativeTo: self.webView.url) {
                            self.downloadFavicon(url: rootUrl, completion: completion)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }.resume()
        }
    }

    /// 下载图标数据的辅助方法
    private func downloadFavicon(url: URL, completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, UIImage(data: data) != nil {
                    completion(data)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
}
