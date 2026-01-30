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

// Framework imports

/// 页面缓存调试面板视图控制器
/// 显示缓存规则、已缓存页面，支持层级展开式查看
public class WebCacheDebugPanelViewController: UIViewController {

    // MARK: - Properties

    /// 规则及其关联的缓存页面
    private var rulesWithPages: [RuleWithPages] = []

    /// 当前搜索文本
    private var searchText: String = ""

    /// Dispose bag
    private let disposeBag = DisposeBag()

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.backgroundColor = .systemBackground
        tv.separatorStyle = .singleLine
        tv.register(SectionHeaderCell.self, forCellReuseIdentifier: "SectionHeaderCell")
        tv.register(RuleHeaderCell.self, forCellReuseIdentifier: "RuleHeaderCell")
        tv.register(PageCell.self, forCellReuseIdentifier: "PageCell")
        tv.register(ExcludePatternCell.self, forCellReuseIdentifier: "ExcludePatternCell")
        tv.register(AddRuleCell.self, forCellReuseIdentifier: "AddRuleCell")
        return tv
    }()

    private lazy var toolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.barTintColor = .systemBackground
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
        // 每次显示时自动刷新数据
        loadData()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustToolbarFrame()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "页面缓存"
        view.backgroundColor = .systemBackground

        // 导航栏按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissPanel)
        )

        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(toolbar)

        // 布局
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

    private func loadData() {
        // 获取所有规则
        let rules = PageCacheRuleManager.shared.getAllRules()

        // 获取所有已缓存的页面
        let cachedPages = WebPageOfflineCacheManager.shared.getCachedPages()

        // 调试信息
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

        // 为每个规则关联其缓存页面
        rulesWithPages = rules.map { rule in
            let pages = cachedPages.filter { $0.ruleId == rule.id }
            print("📊 规则 '\(rule.name)' (ID: \(rule.id)) 匹配到 \(pages.count) 个缓存页面")
            return RuleWithPages(rule: rule, cachedPages: pages, isExpanded: false)
        }

        // 按缓存时间排序
        rulesWithPages.sort { $0.rule.createdAt > $1.rule.createdAt }

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func dismissPanel() {
        dismiss(animated: true)
    }

    @objc private func clearAllCached() {
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

    @objc private func resetRules() {
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

    @objc private func testCache() {
        // 使用 example.com 测试缓存
        let testURL = URL(string: "https://example.com")!
        let testRule = PageCacheRule(
            name: "测试规则",
            includePatterns: ["https://example.com/**"],
            excludePatterns: []
        )

        print("🧪 ========================================")
        print("🧪 开始测试缓存功能...")
        print("📝 测试URL: \(testURL.absoluteString)")
        print("📝 测试规则: \(testRule.name)")
        print("📝 测试规则ID: \(testRule.id)")
        print("📝 测试规则模式: \(testRule.includePatterns)")
        print("🧪 ========================================")

        WebBridgeLogger.shared.info("🧪 开始测试缓存功能...")
        WebBridgeLogger.shared.info("📝 测试URL: \(testURL.absoluteString)")
        WebBridgeLogger.shared.info("📝 测试规则: \(testRule.name), ID: \(testRule.id)")

        WebPageOfflineCacheManager.shared.cachePage(
            url: testURL,
            rule: testRule
        ) { progress in
            let percent = Int(progress * 100)
            print("📊 缓存进度: \(percent)%")
            WebBridgeLogger.shared.info("📊 缓存进度: \(percent)%")
        } completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pageInfo):
                print("✅ ========================================")
                print("✅ 测试缓存成功！")
                print("- URL: \(pageInfo.url)")
                print("- 标题: \(pageInfo.title)")
                print("- 资源数: \(pageInfo.resourceCount)")
                print("- 大小: \(pageInfo.formattedSize)")
                print("- 规则ID: \(pageInfo.ruleId)")
                print("- 规则名称: \(pageInfo.ruleName)")
                print("✅ ========================================")

                // 验证是否真的保存到了数据库
                let allCachedPages = WebPageOfflineCacheManager.shared.getCachedPages()
                print("📦 数据库中的缓存页面数量: \(allCachedPages.count)")
                for page in allCachedPages {
                    print("  - \(page.url), ruleId: \(page.ruleId)")
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
                print("❌ ========================================")
                print("❌ 测试缓存失败: \(error.localizedDescription)")
                print("❌ ========================================")
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

    private func addRule() {
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

    private func deleteRule(ruleId: String) {
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

    private func toggleRuleEnabled(ruleId: String) {
        guard let index = rulesWithPages.firstIndex(where: { $0.rule.id == ruleId }) else { return }
        var rule = rulesWithPages[index].rule
        rule.isEnabled.toggle()
        _ = PageCacheRuleManager.shared.updateRule(rule)
        rulesWithPages[index].rule = rule
        tableView.reloadData()
    }

    private func toggleRuleExpanded(ruleId: String) {
        guard let index = rulesWithPages.firstIndex(where: { $0.rule.id == ruleId }) else { return }
        rulesWithPages[index].isExpanded.toggle()
        tableView.reloadData()
    }

    private func addExcludePattern(ruleId: String) {
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

    private func removeExcludePattern(ruleId: String, excludePattern: String) {
        guard let index = rulesWithPages.firstIndex(where: { $0.rule.id == ruleId }) else { return }
        var rule = rulesWithPages[index].rule
        rule.excludePatterns.removeAll { $0 == excludePattern }
        _ = PageCacheRuleManager.shared.updateRule(rule)
        loadData()
    }

    // MARK: - Page Actions

    private func openCachedPage(_ pageInfo: CachedPageInfo) {
        // TODO: 打开已缓存的页面
        WebBridgeLogger.shared.info("Opening cached page: \(pageInfo.url)")
    }

    private func refreshCachedPage(_ pageInfo: CachedPageInfo) {
        WebPageOfflineCacheManager.shared.refreshCachedPage(pageId: pageInfo.id) { progress in
            // 进度回调
        } completion: { result in
            switch result {
            case .success:
                self.loadData()
            case .failure(let error):
                WebBridgeLogger.shared.error("Failed to refresh: \(error.localizedDescription)")
            }
        }
    }

    private func deleteCachedPage(_ pageInfo: CachedPageInfo) {
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

// MARK: - UITableViewDataSource

extension WebCacheDebugPanelViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        // 1. 添加规则 section
        // 2. 每个规则 section (可能展开显示页面)
        return 1 + rulesWithPages.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // 添加规则 section
            return 1
        } else {
            let ruleIndex = section - 1
            guard ruleIndex < rulesWithPages.count else { return 0 }

            let ruleWithPages = rulesWithPages[ruleIndex]
            if ruleWithPages.isExpanded {
                // 规则 header + 排除模式 + 缓存页面
                return 1 + ruleWithPages.rule.excludePatterns.count + ruleWithPages.cachedPages.count
            } else {
                // 只显示规则 header
                return 1
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension WebCacheDebugPanelViewController: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddRuleCell", for: indexPath) as! AddRuleCell
            cell.onAddRule = { [weak self] in
                self?.addRule()
            }
            return cell
        } else {
            let ruleIndex = indexPath.section - 1
            guard ruleIndex < rulesWithPages.count else { return UITableViewCell() }

            let ruleWithPages = rulesWithPages[ruleIndex]
            let rule = ruleWithPages.rule

            if indexPath.row == 0 {
                // 规则 header cell
                let cell = tableView.dequeueReusableCell(withIdentifier: "RuleHeaderCell", for: indexPath) as! RuleHeaderCell
                cell.configure(
                    rule: rule,
                    cachedPagesCount: ruleWithPages.cachedPages.count,
                    totalSize: ruleWithPages.totalSize,
                    isExpanded: ruleWithPages.isExpanded
                )
                cell.onToggle = { [weak self] in
                    self?.toggleRuleExpanded(ruleId: rule.id)
                }
                cell.onDelete = { [weak self] in
                    self?.deleteRule(ruleId: rule.id)
                }
                cell.onAddExclude = { [weak self] in
                    self?.addExcludePattern(ruleId: rule.id)
                }
                return cell
            } else if ruleWithPages.isExpanded {
                let adjustedRow = indexPath.row - 1

                // 排除模式 cells
                if adjustedRow < rule.excludePatterns.count {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "ExcludePatternCell", for: indexPath) as! ExcludePatternCell
                    let pattern = rule.excludePatterns[adjustedRow]
                    cell.configure(pattern: pattern)
                    cell.onRemove = { [weak self] in
                        self?.removeExcludePattern(ruleId: rule.id, excludePattern: pattern)
                    }
                    return cell
                }

                // 缓存页面 cells
                let pageIndex = adjustedRow - rule.excludePatterns.count
                if pageIndex < ruleWithPages.cachedPages.count {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "PageCell", for: indexPath) as! PageCell
                    let pageInfo = ruleWithPages.cachedPages[pageIndex]
                    cell.configure(pageInfo: pageInfo)
                    cell.onOpen = { [weak self] in
                        self?.openCachedPage(pageInfo)
                    }
                    cell.onRefresh = { [weak self] in
                        self?.refreshCachedPage(pageInfo)
                    }
                    cell.onDelete = { [weak self] in
                        self?.deleteCachedPage(pageInfo)
                    }
                    return cell
                }
            }
        }

        return UITableViewCell()
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 60
        } else {
            let ruleIndex = indexPath.section - 1
            guard ruleIndex < rulesWithPages.count else { return 44 }

            let ruleWithPages = rulesWithPages[ruleIndex]

            if indexPath.row == 0 {
                return ruleWithPages.isExpanded ? 120 : 80
            } else if ruleWithPages.isExpanded {
                let adjustedRow = indexPath.row - 1
                if adjustedRow < ruleWithPages.rule.excludePatterns.count {
                    return 44
                }
                return 80
            }
        }

        return 44
    }
}

// MARK: - Custom Cells

private class AddRuleCell: UITableViewCell {
    var onAddRule: (() -> Void)?

    private let addButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("+ 添加规则", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        return btn
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .systemBackground
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    }

    @objc private func addButtonTapped() {
        onAddRule?()
    }
}

private class RuleHeaderCell: UITableViewCell {
    var onToggle: (() -> Void)?
    var onDelete: (() -> Void)?
    var onAddExclude: (() -> Void)?

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let expandButton = UIButton()
    private let patternLabel = UILabel()
    private let statsLabel = UILabel()
    private let excludeLabel = UILabel()
    private let deleteButton = UIButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        contentView.addSubview(containerView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        containerView.addSubview(titleLabel)

        expandButton.setTitle("▼", for: .normal)
        expandButton.setTitleColor(.systemGray, for: .normal)
        expandButton.titleLabel?.font = .systemFont(ofSize: 14)
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)
        containerView.addSubview(expandButton)

        patternLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        patternLabel.textColor = .secondaryLabel
        patternLabel.numberOfLines = 2
        containerView.addSubview(patternLabel)

        statsLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statsLabel.textColor = .secondaryLabel
        containerView.addSubview(statsLabel)

        excludeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        excludeLabel.textColor = .systemOrange
        excludeLabel.text = "排除模式..."
        containerView.addSubview(excludeLabel)

        deleteButton.setTitle("删除", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        contentView.addSubview(deleteButton)

        let addButton = UIButton(type: .system)
        addButton.setTitle("+ 排除", for: .normal)
        addButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        addButton.setTitleColor(.systemOrange, for: .normal)
        addButton.addTarget(self, action: #selector(addExcludeTapped), for: .touchUpInside)
        containerView.addSubview(addButton)

        // Layout
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(6)
            make.left.equalToSuperview().inset(12)
            make.right.equalTo(deleteButton.snp.left).offset(-8)
            make.bottom.equalToSuperview().inset(-6)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.left.equalToSuperview().inset(12)
            make.right.equalTo(expandButton.snp.left).offset(-8)
        }

        expandButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.right.equalToSuperview().inset(-12)
            make.width.height.equalTo(32)
        }

        patternLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalTo(titleLabel)
            make.right.equalToSuperview().inset(-12)
        }

        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(patternLabel.snp.bottom).offset(8)
            make.left.equalTo(titleLabel)
        }

        excludeLabel.snp.makeConstraints { make in
            make.top.equalTo(statsLabel.snp.bottom).offset(4)
            make.left.equalTo(titleLabel)
        }

        addButton.snp.makeConstraints { make in
            make.top.equalTo(excludeLabel.snp.bottom).offset(8)
            make.left.equalTo(titleLabel)
            make.height.equalTo(28)
        }

        deleteButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().inset(-12)
            make.width.equalTo(44)
        }
    }

    func configure(
        rule: PageCacheRule,
        cachedPagesCount: Int,
        totalSize: Int64,
        isExpanded: Bool
    ) {
        titleLabel.text = rule.name
        expandButton.setTitle(isExpanded ? "▼" : "▶", for: .normal)

        let includeStr = rule.includePatterns.count == 1
            ? rule.includePatterns[0]
            : "\(rule.includePatterns.count) 个包含模式"
        patternLabel.text = includeStr

        let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        statsLabel.text = "已缓存 \(cachedPagesCount) 个页面 | \(sizeStr)"

        if rule.excludePatterns.isEmpty {
            excludeLabel.isHidden = true
        } else {
            excludeLabel.isHidden = false
            excludeLabel.text = "排除: \(rule.excludePatterns.count) 个模式"
        }
    }

    @objc private func expandTapped() {
        onToggle?()
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    @objc private func addExcludeTapped() {
        onAddExclude?()
    }
}

private class ExcludePatternCell: UITableViewCell {
    var onRemove: (() -> Void)?

    private let containerView = UIView()
    private let patternLabel = UILabel()
    private let removeButton = UIButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        containerView.backgroundColor = .tertiarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        contentView.addSubview(containerView)

        patternLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        patternLabel.textColor = .secondaryLabel
        patternLabel.numberOfLines = 1
        containerView.addSubview(patternLabel)

        removeButton.setTitle("✗", for: .normal)
        removeButton.setTitleColor(.systemRed, for: .normal)
        removeButton.titleLabel?.font = .systemFont(ofSize: 14)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        containerView.addSubview(removeButton)

        // Layout
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(2)
            make.left.equalToSuperview().inset(32)
            make.right.equalToSuperview().inset(-12)
            make.bottom.equalToSuperview().inset(-2)
        }

        patternLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().inset(8)
            make.right.equalTo(removeButton.snp.left).offset(-8)
        }

        removeButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().inset(-8)
            make.width.height.equalTo(24)
        }
    }

    func configure(pattern: String) {
        patternLabel.text = "✗ \(pattern)"
    }

    @objc private func removeTapped() {
        onRemove?()
    }
}

private class PageCell: UITableViewCell {
    var onOpen: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onDelete: (() -> Void)?

    private let containerView = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let statsLabel = UILabel()

    private let openButton = UIButton()
    private let refreshButton = UIButton()
    private let deleteButton = UIButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        contentView.addSubview(containerView)

        iconLabel.font = .systemFont(ofSize: 14)
        iconLabel.text = "📄"
        containerView.addSubview(iconLabel)

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label
        containerView.addSubview(titleLabel)

        urlLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        containerView.addSubview(urlLabel)

        statsLabel.font = .systemFont(ofSize: 11, weight: .regular)
        statsLabel.textColor = .secondaryLabel
        containerView.addSubview(statsLabel)

        let stackView = UIStackView(arrangedSubviews: [openButton, refreshButton, deleteButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        contentView.addSubview(stackView)

        openButton.setTitle("打开", for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        openButton.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        openButton.layer.cornerRadius = 4
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        refreshButton.setTitle("刷新", for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        refreshButton.backgroundColor = .systemGreen.withAlphaComponent(0.1)
        refreshButton.setTitleColor(.systemGreen, for: .normal)
        refreshButton.layer.cornerRadius = 4
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        deleteButton.setTitle("删除", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        deleteButton.backgroundColor = .systemRed.withAlphaComponent(0.1)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.layer.cornerRadius = 4
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        // Layout
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(4)
            make.left.equalToSuperview().inset(12)
            make.right.equalTo(stackView.snp.left).offset(-8)
            make.bottom.equalToSuperview().inset(-4)
        }

        iconLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.left.equalToSuperview().inset(8)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.left.equalTo(iconLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(-8)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.left.equalTo(titleLabel)
            make.right.equalToSuperview().inset(-8)
        }

        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalTo(titleLabel)
            make.right.equalToSuperview().inset(-8)
        }

        stackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().inset(-8)
            make.height.equalTo(28)
        }

        // Bottom constraint
        statsLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(-8)
        }
    }

    func configure(pageInfo: CachedPageInfo) {
        titleLabel.text = pageInfo.title
        urlLabel.text = pageInfo.url

        if pageInfo.isExcluded {
            iconLabel.text = "🚫"
            statsLabel.text = "已排除"
            statsLabel.textColor = .systemRed
        } else {
            iconLabel.text = "📄"
            statsLabel.text = "\(pageInfo.resourceCount) 资源 | \(pageInfo.formattedSize) | \(pageInfo.formattedCachedAt)"
            statsLabel.textColor = .secondaryLabel
        }
    }

    @objc private func openTapped() {
        onOpen?()
    }

    @objc private func refreshTapped() {
        onRefresh?()
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}

private class SectionHeaderCell: UITableViewCell {
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.text = "📋 缓存规则"
        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.left.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(-12)
        }
    }
}
