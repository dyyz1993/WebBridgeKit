//
//  WebCacheDebugPanelViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import RxSwift

/// 页面缓存调试面板视图控制器
/// 显示缓存规则、已缓存页面，支持层级展开式查看
public class WebCacheDebugPanelViewController: UIViewController {

    // MARK: - Properties

    /// 规则及其关联的缓存页面
    var rulesWithPages: [RuleWithPages] = []

    /// 当前搜索文本
    private var searchText: String = ""

    /// Dispose bag
    private let disposeBag = DisposeBag()

    // MARK: - UI Components

    lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.backgroundColor = ThemeTokens.Color.background
        tv.separatorStyle = .singleLine
        tv.register(SectionHeaderCell.self, forCellReuseIdentifier: "SectionHeaderCell")
        tv.register(RuleHeaderCell.self, forCellReuseIdentifier: "RuleHeaderCell")
        tv.register(PageCell.self, forCellReuseIdentifier: "PageCell")
        tv.register(ExcludePatternCell.self, forCellReuseIdentifier: "ExcludePatternCell")
        tv.register(AddRuleCell.self, forCellReuseIdentifier: "AddRuleCell")
        return tv
    }()

    lazy var toolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.barTintColor = ThemeTokens.Color.background
        tb.isTranslucent = false

        let resetRulesItem = UIBarButtonItem(
            title: "重置规则",
            style: .plain,
            target: self,
            action: #selector(resetRules)
        )

        let testCacheItem = UIBarButtonItem(
            title: "测试",
            style: .plain,
            target: self,
            action: #selector(testCache)
        )

        let clearItem = UIBarButtonItem(
            title: "清空",
            style: .plain,
            target: self,
            action: #selector(clearAllCached)
        )

        let flexibleItem = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        let refreshItem = UIBarButtonItem(
            title: "刷新",
            style: .plain,
            target: self,
            action: #selector(refreshData)
        )

        tb.items = [resetRulesItem, testCacheItem, clearItem, flexibleItem, refreshItem]
        return tb
    }()

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustToolbarFrame()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "页面缓存"
        view.backgroundColor = ThemeTokens.Color.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissPanel)
        )

        view.addSubview(tableView)
        view.addSubview(toolbar)

        tableView.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(toolbar.snp.top)
        }
    }

    private func adjustToolbarFrame() {
        let toolbarHeight: CGFloat = 44
        toolbar.frame = CGRect(
            x: 0,
            y: view.bounds.height - toolbarHeight - view.safeAreaInsets.bottom,
            width: view.bounds.width,
            height: toolbarHeight + view.safeAreaInsets.bottom
        )
    }

    // MARK: - Data Loading

    @objc private func refreshData() {
        loadData()
    }

    func loadData() {
        let rules = PageCacheRuleManager.shared.getAllRules()
        let cachedPages = WebPageOfflineCacheManager.shared.getCachedPages()

        print("📋 ========================================")
        print("📋 loadData 调试信息:")
        print("- 规则数量: \(rules.count)")
        for rule in rules {
            print("  - 规则: \(rule.name), ID: \(rule.id)")
        }
        print("- 缓存页面数量: \(cachedPages.count)")
        for page in cachedPages {
            print("  - 页面: \(page.url), ruleId: \(page.ruleId), ruleName: \(page.ruleName)")
        }
        print("📋 ========================================")

        rulesWithPages = rules.map { rule in
            let pages = cachedPages.filter { $0.ruleId == rule.id }
            print("📊 规则 '\(rule.name)' (ID: \(rule.id)) 匹配到 \(pages.count) 个缓存页面")
            return RuleWithPages(rule: rule, cachedPages: pages, isExpanded: false)
        }

        rulesWithPages.sort { $0.rule.createdAt > $1.rule.createdAt }

        tableView.reloadData()
    }
}
