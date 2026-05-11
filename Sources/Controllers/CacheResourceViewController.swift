//
//  CacheResourceViewController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

/// 缓存资源管理视图控制器
public class CacheResourceViewController: BaseViewController<CacheResourceViewModel> {

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.register(CacheResourceCell.self, forCellReuseIdentifier: CacheResourceCell.identifier)
        tv.delegate = self
        return tv
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private let toolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.barTintColor = ThemeTokens.Color.background
        tb.isTranslucent = false
        return tb
    }()

    private let selectAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("全选", for: .normal)
        button.accessibilityLabel = "全选缓存资源"
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        return button
    }()

    private let deselectAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.backgroundColor = ThemeTokens.Color.textSecondary.withAlphaComponent(0.1)
        button.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
        return button
    }()

    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("删除选中", for: .normal)
        button.accessibilityLabel = "删除选中的缓存资源"
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.backgroundColor = ThemeTokens.Color.error.withAlphaComponent(0.1)
        button.setTitleColor(ThemeTokens.Color.error, for: .normal)
        return button
    }()

    private let clearAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("清空全部", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.backgroundColor = ThemeTokens.Color.error.withAlphaComponent(0.1)
        button.setTitleColor(ThemeTokens.Color.error, for: .normal)
        return button
    }()

    private let selectedCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = ThemeTokens.Color.textSecondary
        label.text = "已选 0 项"
        return label
    }()

    private let totalCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = ThemeTokens.Color.textTertiary
        label.text = "共 0 个资源"
        return label
    }()

    private let loadingView = LoadingView()

    // MARK: - Properties

    private let url: URL
    private var currentSections: [CacheResourceSection] = []

    // MARK: - Initialization

    public init(url: URL) {
        self.url = url
        super.init(viewModel: CacheResourceViewModel())
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "缓存资源"
    }

    // MARK: - Setup UI

    public override func makeUI() {
        view.backgroundColor = ThemeTokens.Color.background

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingView)

        // 创建工具栏容器
        let toolbarContainer = UIView()
        toolbarContainer.backgroundColor = ThemeTokens.Color.background
        view.addSubview(toolbarContainer)

        toolbarContainer.addSubview(toolbar)
        toolbarContainer.addSubview(selectedCountLabel)
        toolbarContainer.addSubview(totalCountLabel)

        // 工具栏按钮容器
        let buttonStackView = UIStackView(arrangedSubviews: [
            selectAllButton,
            deselectAllButton,
            deleteButton,
            clearAllButton
        ])
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = ThemeTokens.Spacing.sm
        buttonStackView.distribution = .fillEqually
        toolbarContainer.addSubview(buttonStackView)

        // 布局
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(toolbarContainer.snp.top)
        }

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        toolbarContainer.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(88 + view.safeAreaInsets.bottom)
        }

        toolbar.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(44)
        }

        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(toolbar.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(36)
        }

        selectedCountLabel.snp.makeConstraints { make in
            make.top.equalTo(buttonStackView.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
        }

        totalCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(selectedCountLabel)
            make.right.equalToSuperview().offset(-16)
        }

        // 配置空状态
        emptyStateView.configure(
            icon: "tray",
            title: "暂无缓存资源",
            description: "该页面暂无缓存的资源文件",
            actionTitle: nil
        )

        // 按钮事件
        selectAllButton.addTarget(self, action: #selector(selectAllTapped), for: .touchUpInside)
        deselectAllButton.addTarget(self, action: #selector(deselectAllTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)
        clearAllButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)

        // 导航栏右侧关闭按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )
    }

    // MARK: - Bind ViewModel

    public override func bindViewModel() {
        let loadResources = Driver.just(url)
        let selectAll = selectAllButton.rx.tap.asDriver()
        let deselectAll = deselectAllButton.rx.tap.asDriver()
        let deleteSelected = deleteButton.rx.tap.asDriver()
        let clearAll = clearAllButton.rx.tap.asDriver()
        let itemDelete = Observable<String>.empty().asDriver(onErrorJustReturn: "")

        let input = CacheResourceViewModel.Input(
            loadResources: loadResources,
            selectAll: selectAll,
            deselectAll: deselectAll,
            deleteSelected: deleteSelected,
            clearAll: clearAll,
            itemDelete: itemDelete
        )

        let output = viewModel.transform(input: input)

        // 绑定资源列表
        output.resources
            .drive(onNext: { [weak self] sections in
                self?.currentSections = sections
                self?.updateTableView(sections: sections)
            })
            .disposed(by: rx)

        // 绑定空状态
        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                self?.emptyStateView.isHidden = !isEmpty
                self?.tableView.isHidden = isEmpty
            })
            .disposed(by: rx)

        // 绑定选中数量
        output.selectedCount
            .drive(onNext: { [weak self] count in
                self?.selectedCountLabel.text = "已选 \(count) 项"
                self?.updateDeleteButtonState(count: count)
            })
            .disposed(by: rx)

        // 绑定总数
        output.totalCount
            .drive(onNext: { [weak self] text in
                self?.totalCountLabel.text = text
            })
            .disposed(by: rx)

        // 绑定加载状态
        output.loading
            .drive(onNext: { [weak self] loading in
                self?.loadingView.isHidden = !loading
            })
            .disposed(by: rx)

        // 绑定删除完成
        output.deletionCompleted
            .drive(onNext: { [weak self] in
                self?.showAlert(title: "成功", message: "删除完成")
            })
            .disposed(by: rx)
    }

    // MARK: - Private Methods

    private func updateTableView(sections: [CacheResourceSection]) {
        // Simply reload the table view - the UITableViewDataSource handles the data
        tableView.reloadData()
    }

    private func updateDeleteButtonState(count: Int) {
        deleteButton.isEnabled = count > 0
        deleteButton.alpha = count > 0 ? 1.0 : 0.5
    }

    // MARK: - Actions

    @objc private func selectAllTapped() {
        // 通过重新触发输入来全选
        updateTableView(sections: currentSections)
    }

    @objc private func deselectAllTapped() {
        viewModel.deselectAllResources()
        updateTableView(sections: currentSections)
    }

    @objc private func deleteSelectedTapped() {
        let alert = UIAlertController(
            title: "删除选中资源",
            message: "确定要删除选中的缓存资源吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.deleteSelectedResources()
            self.viewModel.deselectAllResources()
        })

        present(alert, animated: true)
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "清空所有缓存",
            message: "确定要清空该页面的所有缓存资源吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            self?.viewModel.clearAllResources()
        })

        present(alert, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension CacheResourceViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return currentSections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSections[section].items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CacheResourceCell.identifier,
            for: indexPath
        ) as! CacheResourceCell

        let section = currentSections[indexPath.section]
        let item = section.items[indexPath.row]

        cell.item = item
        cell.isItemSelected = viewModel.isSelected(key: item.key)
        cell.onSelectionToggle = { [weak self] key in
            self?.viewModel.toggleSelection(key: key)
            // Reload only the specific row for better performance
            if let self = self {
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }

        return cell
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = currentSections[section]
        return "\(section.type.displayName) - \(section.items.count) 个文件 (\(section.formattedTotalSize))"
    }
}

// MARK: - UITableViewDelegate

extension CacheResourceViewController: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = currentSections[indexPath.section]
        let item = section.items[indexPath.row]

        // 显示资源详情
        let alert = UIAlertController(
            title: item.fileName,
            message: """
            类型: \(item.type.displayName)
            大小: \(item.formattedSize)
            日期: \(DateFormatter.localizedString(from: item.date, dateStyle: .short, timeStyle: .short))
            路径: \(item.url)
            """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))

        present(alert, animated: true)
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section = currentSections[indexPath.section]
        let item = section.items[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }

            let alert = UIAlertController(
                title: "删除资源",
                message: "确定要删除 '\(item.fileName)' 吗？",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                self.viewModel.deleteResource(key: item.key)
                self.viewModel.deselectAllResources()
                completion(true)
            })

            self.present(alert, animated: true)
        }

        deleteAction.backgroundColor = ThemeTokens.Color.error

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}
