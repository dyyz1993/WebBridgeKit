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
            title: "浏览器菜单",
            message: nil,
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "刷新", style: .default) { [weak self] _ in
            self?.webView.reload()
        })

        // 容器构建（DREL_CONTAINER_ONLY）下宿主设置 Provider 恒返回 nil，
        // 菜单里摆「应用设置」只会弹「设置模块不可用」——按构建能力收口，
        // 桥能力开启时才暴露该入口。
        if viewModel.managedHTMLAppID != nil, DrelContainerBuildPolicy.nativeBridgeEnabled {
            alertController.addAction(UIAlertAction(title: "应用设置", style: .default) { [weak self] _ in
                self?.showManagedHTMLAppSettings()
            })
        }

        let toggleTitle = hideNavBar ? "显示导航栏" : "隐藏导航栏"
        alertController.addAction(UIAlertAction(title: toggleTitle, style: .default) { [weak self] _ in
            self?.setNavigationBarHidden(!(self?.hideNavBar ?? false))
        })

        let statusBarToggleTitle = isStatusBarHidden ? "显示状态栏" : "隐藏状态栏"
        alertController.addAction(UIAlertAction(title: statusBarToggleTitle, style: .default) { [weak self] _ in
            self?.setStatusBarHidden(!(self?.isStatusBarHidden ?? false))
        })

        // 收藏入口与全屏胶囊共用 favoriteEntryURL 语义：managed 应用页面
        // 渲染自 custom:// scheme，绝不能把原始页面 URL 写进收藏表；托管的
        // https 入口 / 普通网页才可持久化。动作复用 toggleImmersiveFavorite，
        // 带收藏 HUD 反馈并同步胶囊收藏态。
        if let entryURL = favoriteEntryURL {
            let favoriteService = ServiceLocator.favorite
            let isFavorited = favoriteService.findFavorite(url: entryURL) != nil
            let favoriteTitle = isFavorited ? "取消收藏" : "收藏页面"

            alertController.addAction(UIAlertAction(title: favoriteTitle, style: .default) { [weak self] _ in
                self?.toggleImmersiveFavorite()
            })
        }

        alertController.addAction(UIAlertAction(title: "书签", style: .default) { [weak self] _ in
            self?.showBookmarks()
        })

        // 开发者工具仅在 DEBUG 构建进入浏览器菜单；Release 用户菜单只保留
        // 面向使用者的操作（刷新/显隐/收藏/书签/应用设置/权限/缓存统计）。
        #if DEBUG
        alertController.addAction(UIAlertAction(title: NSLocalizedString("[BRIDGE] JS Bridge Test", comment: ""), style: .default) { [weak self] _ in
            self?.loadJSBridgeTestPage()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("[EMOJI] Voice Game", comment: ""), style: .default) { [weak self] _ in
            self?.loadGamePage()
        })
        #endif

        if let appID = htmlAppID,
           let manifest = HTMLAppRuntimeCenter.shared.trustRegistry.manifest(for: appID),
           let presenter = WebBrowserManager.shared.appPermissionSettingsPresenter {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("[SETTINGS] 应用设置", comment: ""), style: .default) { [weak self] _ in
                guard let self else { return }
                presenter(self, manifest)
            })
        }

        // 原生权限管理入口（替代旧的 loadPermissionsPage 网页版——用户反馈
        // 菜单里进权限管理不应是网页）
        if let presenter = WebBrowserManager.shared.webGrantsPresenter {
            alertController.addAction(UIAlertAction(title: "权限管理", style: .default) { [weak self] _ in
                guard let self else { return }
                presenter(self)
            })
        }

        alertController.addAction(UIAlertAction(title: "缓存统计", style: .default) { [weak self] _ in
            self?.showSystemCacheStatistics()
        })

        #if DEBUG
        alertController.addAction(UIAlertAction(title: NSLocalizedString("[FOLDER] Cache Debug", comment: ""), style: .default) { [weak self] _ in
            self?.showCacheDebugPanel()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("[STATS] Performance Info", comment: ""), style: .default) { [weak self] _ in
            self?.showPerformanceInfo()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("[SEARCH] Debug Info", comment: ""), style: .default) { [weak self] _ in
            self?.showDebugInfo()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("[HOME] Welcome Page", comment: ""), style: .default) { [weak self] _ in
            self?.loadWelcomePage()
        })
        #endif

        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))

        present(alertController, animated: true)
    }

    private func showManagedHTMLAppSettings() {
        guard let appID = viewModel.managedHTMLAppID,
              let settings = HTMLAppHostUI.settingsViewControllerProvider?
                .makeHTMLAppSettingsViewController(
                    appID: appID,
                    documentURL: webView.url ?? viewModel.managedHTMLAppDocumentURL
                ) else {
            let alert = UIAlertController(
                title: "设置模块不可用",
                message: "当前宿主没有提供这个 PWA 的应用设置页面。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
            return
        }
        // 权限中心要求全屏（无底部 Tab，靠导航栏返回）
        settings.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(settings, animated: true)
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
                    title: "缓存统计",
                    message: message.isEmpty ? "暂无缓存数据" : message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "好", style: .default))
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
            "[MOBILE] 当前 URL": webView.url?.absoluteString ?? "None",
            "[DOC] 页面标题": webView.title ?? "None",
            "[BACK] 可以后退": webView.canGoBack ? "是" : "否",
            "[NEXT] 可以前进": webView.canGoForward ? "是" : "否",
            "[SYNC] 加载中": webView.isLoading ? "是" : "否",
            "[STATS] 加载进度": String(format: "%.1f%%", webView.estimatedProgress * 100),
            "[CTRL] 导航栏": hideNavBar ? "隐藏" : "显示",
            "[STATS] 状态栏": isStatusBarHidden ? "隐藏" : "显示"
        ]

        let message = info.map { "\($0.key): \($0.value)" }.joined(separator: "\n")

        let alert = UIAlertController(
            title: "[SEARCH] 调试信息",
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
