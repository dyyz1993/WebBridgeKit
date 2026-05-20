//
//  WebCacheDebugPanelViewController+Actions.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit

// MARK: - Actions

extension WebCacheDebugPanelViewController {

    @objc func dismissPanel() {
        dismiss(animated: true)
    }

    @objc func clearAllCached() {
        let alert = UIAlertController(
            title: "清空所有缓存",
            message: "确定要清空所有已缓存的页面吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { _ in
            WebPageOfflineCacheManager.shared.clearAllCache()
            self.loadData()
        })

        present(alert, animated: true)
    }

    @objc func resetRules() {
        let alert = UIAlertController(
            title: "重置预设规则",
            message: "这将清空所有规则并恢复预设规则（百度、VIP视频、GitHub），确定吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { _ in
            let success = PageCacheRuleManager.shared.resetToPresetRules()
            if success {
                WebBridgeLogger.shared.info("✅ 规则已重置为预设规则")
                self.loadData()
            } else {
                WebBridgeLogger.shared.error("❌ 规则重置失败")
            }
        })

        present(alert, animated: true)
    }

    @objc func testCache() {
        guard let testURL = URL(string: "https://example.com") else {
            StructuredLogger.shared.error("❌ [DebugPanel] Failed to create test URL", category: .navigation)
            return
        }
        let testRule = PageCacheRule(
            name: "测试规则",
            includePatterns: ["https://example.com/**"],
            excludePatterns: []
        )

        StructuredLogger.shared.debug("🧪 ========================================", category: .ui)
        StructuredLogger.shared.debug("🧪 开始测试缓存功能...", category: .ui)
        StructuredLogger.shared.debug("📝 测试URL: \(testURL.absoluteString)", category: .navigation)
        StructuredLogger.shared.debug("📝 测试规则: \(testRule.name)", category: .ui)
        StructuredLogger.shared.debug("📝 测试规则ID: \(testRule.id)", category: .ui)
        StructuredLogger.shared.debug("📝 测试规则模式: \(testRule.includePatterns)", category: .ui)
        StructuredLogger.shared.debug("🧪 ========================================", category: .ui)

        WebBridgeLogger.shared.info("🧪 开始测试缓存功能...")
        WebBridgeLogger.shared.info("📝 测试URL: \(testURL.absoluteString)")
        WebBridgeLogger.shared.info("📝 测试规则: \(testRule.name), ID: \(testRule.id)")

        WebPageOfflineCacheManager.shared.cachePage(
            url: testURL,
            rule: testRule
        ) { progress in
            let percent = Int(progress * 100)
            StructuredLogger.shared.debug("📊 缓存进度: \(percent)%", category: .ui)
            WebBridgeLogger.shared.info("📊 缓存进度: \(percent)%")
        } completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pageInfo):
                StructuredLogger.shared.info("✅ ========================================", category: .ui)
                StructuredLogger.shared.info("✅ 测试缓存成功！", category: .ui)
                StructuredLogger.shared.debug("- URL: \(pageInfo.url)", category: .navigation)
                StructuredLogger.shared.debug("- 标题: \(pageInfo.title)", category: .ui)
                StructuredLogger.shared.debug("- 资源数: \(pageInfo.resourceCount)", category: .ui)
                StructuredLogger.shared.debug("- 大小: \(pageInfo.formattedSize)", category: .ui)
                StructuredLogger.shared.debug("- 规则ID: \(pageInfo.ruleId)", category: .ui)
                StructuredLogger.shared.debug("- 规则名称: \(pageInfo.ruleName)", category: .ui)
                StructuredLogger.shared.info("✅ ========================================", category: .ui)

                let allCachedPages = WebPageOfflineCacheManager.shared.getCachedPages()
                StructuredLogger.shared.debug("📦 数据库中的缓存页面数量: \(allCachedPages.count)", category: .cache)
                for page in allCachedPages {
                    StructuredLogger.shared.debug("  - \(page.url), ruleId: \(page.ruleId)", category: .navigation)
                }

                WebBridgeLogger.shared.info("""
                ✅ 测试缓存成功！
                - URL: \(pageInfo.url)
                - 标题: \(pageInfo.title)
                - 资源数: \(pageInfo.resourceCount)
                - 大小: \(pageInfo.formattedSize)
                - 规则ID: \(pageInfo.ruleId)
                - 规则名称: \(pageInfo.ruleName)
                """)
                DispatchQueue.main.async {
                    self.loadData()
                }
            case .failure(let error):
                StructuredLogger.shared.error("❌ ========================================", category: .ui)
                StructuredLogger.shared.error("❌ 测试缓存失败: \(error.localizedDescription)", category: .ui)
                StructuredLogger.shared.error("❌ ========================================", category: .ui)
                WebBridgeLogger.shared.error("❌ 测试缓存失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "测试失败",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - Rule Management

    func addRule() {
        let alert = UIAlertController(
            title: "新增页面缓存规则",
            message: "输入规则名称和包含模式",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "规则名称（如：百度）"
        }

        alert.addTextField { textField in
            textField.placeholder = "包含模式（如：https://*.baidu.com/**）"
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            guard let name = alert.textFields?[0].text,
                  !name.isEmpty,
                  let pattern = alert.textFields?[1].text,
                  !pattern.isEmpty else {
                return
            }

            let rule = PageCacheRule(
                name: name,
                includePatterns: [pattern],
                excludePatterns: []
            )

            if PageCacheRuleManager.shared.addRule(rule) {
                self.loadData()
            }
        })

        present(alert, animated: true)
    }

    func deleteRule(ruleId: String) {
        let alert = UIAlertController(
            title: "删除规则",
            message: "确定要删除此规则吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
            if PageCacheRuleManager.shared.deleteRule(ruleId: ruleId) {
                self.loadData()
            }
        })

        present(alert, animated: true)
    }

    func toggleRuleEnabled(ruleId: String) {
        guard let index = rulesWithPages.firstIndex(where: { $0.rule.id == ruleId }) else { return }
        var rule = rulesWithPages[index].rule
        rule.isEnabled.toggle()
        _ = PageCacheRuleManager.shared.updateRule(rule)
        rulesWithPages[index].rule = rule
        tableView.reloadData()
    }

    func toggleRuleExpanded(ruleId: String) {
        guard let index = rulesWithPages.firstIndex(where: { $0.rule.id == ruleId }) else { return }
        rulesWithPages[index].isExpanded.toggle()
        tableView.reloadData()
    }

    func addExcludePattern(ruleId: String) {
        guard let ruleWithPages = rulesWithPages.first(where: { $0.rule.id == ruleId }) else { return }

        let alert = UIAlertController(
            title: "添加排除模式",
            message: "输入要排除的 Glob 模式",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "排除模式（如：**/login/**）"
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { _ in
            guard let pattern = alert.textFields?.first?.text, !pattern.isEmpty else { return }

            var rule = ruleWithPages.rule
            rule.excludePatterns.append(pattern)
            _ = PageCacheRuleManager.shared.updateRule(rule)
            self.loadData()
        })

        present(alert, animated: true)
    }

    func removeExcludePattern(ruleId: String, excludePattern: String) {
        guard let index = rulesWithPages.firstIndex(where: { $0.rule.id == ruleId }) else { return }
        var rule = rulesWithPages[index].rule
        rule.excludePatterns.removeAll { $0 == excludePattern }
        _ = PageCacheRuleManager.shared.updateRule(rule)
        loadData()
    }

    // MARK: - Page Actions

    func openCachedPage(_ pageInfo: CachedPageInfo) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let history = try? await WebPageHistoryManager.shared.findHistory(id: pageInfo.id),
               let htmlPath = history.htmlPath {
                let fileURL = URL(fileURLWithPath: htmlPath)
                let modalVC = ModalWebViewController(url: fileURL)
                self.present(modalVC, animated: true)
                WebBridgeLogger.shared.info("Opening cached page: \(pageInfo.url)")
            } else {
                WebBridgeLogger.shared.error("Failed to find cached page: \(pageInfo.url)")
            }
        }
    }

    func refreshCachedPage(_ pageInfo: CachedPageInfo) {
        WebPageOfflineCacheManager.shared.refreshCachedPage(pageId: pageInfo.id) { _ in
        } completion: { result in
            switch result {
            case .success:
                self.loadData()
            case .failure(let error):
                WebBridgeLogger.shared.error("Failed to refresh: \(error.localizedDescription)")
            }
        }
    }

    func deleteCachedPage(_ pageInfo: CachedPageInfo) {
        let alert = UIAlertController(
            title: "删除缓存",
            message: "确定要删除此页面的缓存吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
            if WebPageOfflineCacheManager.shared.deleteCachedPage(pageId: pageInfo.id) {
                self.loadData()
            }
        })

        present(alert, animated: true)
    }
}
