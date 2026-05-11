//
//  WebCacheDebugPanelViewController+Cells.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

// MARK: - UITableViewDataSource

extension WebCacheDebugPanelViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + rulesWithPages.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            let ruleIndex = section - 1
            guard ruleIndex < rulesWithPages.count else { return 0 }

            let ruleWithPages = rulesWithPages[ruleIndex]
            if ruleWithPages.isExpanded {
                return 1 + ruleWithPages.rule.excludePatterns.count + ruleWithPages.cachedPages.count
            } else {
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

                if adjustedRow < rule.excludePatterns.count {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "ExcludePatternCell", for: indexPath) as! ExcludePatternCell
                    let pattern = rule.excludePatterns[adjustedRow]
                    cell.configure(pattern: pattern)
                    cell.onRemove = { [weak self] in
                        self?.removeExcludePattern(ruleId: rule.id, excludePattern: pattern)
                    }
                    return cell
                }

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

class AddRuleCell: UITableViewCell {
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
        backgroundColor = ThemeTokens.Color.background
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

class RuleHeaderCell: UITableViewCell {
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

        containerView.backgroundColor = ThemeTokens.Color.surface
        containerView.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        containerView.layer.masksToBounds = true
        contentView.addSubview(containerView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = ThemeTokens.Color.text
        containerView.addSubview(titleLabel)

        expandButton.setTitle("▼", for: .normal)
        expandButton.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
        expandButton.titleLabel?.font = .systemFont(ofSize: 14)
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)
        containerView.addSubview(expandButton)

        patternLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        patternLabel.textColor = ThemeTokens.Color.textSecondary
        patternLabel.numberOfLines = 2
        containerView.addSubview(patternLabel)

        statsLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statsLabel.textColor = ThemeTokens.Color.textSecondary
        containerView.addSubview(statsLabel)

        excludeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        excludeLabel.textColor = ThemeTokens.Color.warning
        excludeLabel.text = "排除模式..."
        containerView.addSubview(excludeLabel)

        deleteButton.setTitle("删除", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        deleteButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        contentView.addSubview(deleteButton)

        let addButton = UIButton(type: .system)
        addButton.setTitle("+ 排除", for: .normal)
        addButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        addButton.setTitleColor(ThemeTokens.Color.warning, for: .normal)
        addButton.addTarget(self, action: #selector(addExcludeTapped), for: .touchUpInside)
        containerView.addSubview(addButton)

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

class ExcludePatternCell: UITableViewCell {
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

        containerView.backgroundColor = ThemeTokens.Color.surface
        containerView.layer.cornerRadius = ThemeTokens.CornerRadius.md
        containerView.layer.masksToBounds = true
        contentView.addSubview(containerView)

        patternLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        patternLabel.textColor = ThemeTokens.Color.textSecondary
        patternLabel.numberOfLines = 1
        containerView.addSubview(patternLabel)

        removeButton.setTitle("✗", for: .normal)
        removeButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        removeButton.titleLabel?.font = .systemFont(ofSize: 14)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        containerView.addSubview(removeButton)

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

class PageCell: UITableViewCell {
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

        containerView.backgroundColor = ThemeTokens.Color.surface
        containerView.layer.cornerRadius = ThemeTokens.CornerRadius.md
        containerView.layer.masksToBounds = true
        contentView.addSubview(containerView)

        iconLabel.font = .systemFont(ofSize: 14)
        iconLabel.text = "📄"
        containerView.addSubview(iconLabel)

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = ThemeTokens.Color.text
        containerView.addSubview(titleLabel)

        urlLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        urlLabel.textColor = ThemeTokens.Color.textSecondary
        urlLabel.numberOfLines = 1
        containerView.addSubview(urlLabel)

        statsLabel.font = .systemFont(ofSize: 11, weight: .regular)
        statsLabel.textColor = ThemeTokens.Color.textSecondary
        containerView.addSubview(statsLabel)

        let stackView = UIStackView(arrangedSubviews: [openButton, refreshButton, deleteButton])
        stackView.axis = .horizontal
        stackView.spacing = ThemeTokens.Spacing.sm
        stackView.distribution = .fillEqually
        contentView.addSubview(stackView)

        openButton.setTitle("打开", for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        openButton.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        openButton.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        refreshButton.setTitle("刷新", for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        refreshButton.backgroundColor = ThemeTokens.Color.success.withAlphaComponent(0.1)
        refreshButton.setTitleColor(ThemeTokens.Color.success, for: .normal)
        refreshButton.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        deleteButton.setTitle("删除", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        deleteButton.backgroundColor = ThemeTokens.Color.error.withAlphaComponent(0.1)
        deleteButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        deleteButton.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

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
            statsLabel.textColor = ThemeTokens.Color.error
        } else {
            iconLabel.text = "📄"
            statsLabel.text = "\(pageInfo.resourceCount) 资源 | \(pageInfo.formattedSize) | \(pageInfo.formattedCachedAt)"
            statsLabel.textColor = ThemeTokens.Color.textSecondary
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

class SectionHeaderCell: UITableViewCell {
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
