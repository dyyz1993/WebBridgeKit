//
//  InboxViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

class InboxViewController: BaseViewController<InboxViewModel> {

    private let scaffold = WBKScreenScaffold(style: .standard)

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.screenTitle
        label.textColor = ThemeTokens.Color.text
        label.text = L10n.tr("tab.inbox")
        label.numberOfLines = 1
        return label
    }()

    private let searchField = WBKSearchField(placeholder: L10n.tr("inbox.search.placeholder"))

    private let filterScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        return sv
    }()

    private let filterStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        stack.alignment = .leading
        return stack
    }()

    private var filterPills: [WBKFilterPill] = []
    private let filterRelay = BehaviorRelay<InboxViewModel.FilterType>(value: .all)

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(InboxMessageCellWrapper.self, forCellReuseIdentifier: InboxMessageCellWrapper.identifier)
        table.register(InboxGroupHeaderCell.self, forCellReuseIdentifier: InboxGroupHeaderCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 84
        table.backgroundColor = ThemeTokens.Color.background
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.contentInset = .zero
        return table
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = ThemeTokens.Color.textTertiary
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    private let emptyState: WBKEmptyState = {
        let es = WBKEmptyState(
            icon: .inbox,
            title: L10n.tr("inbox.empty.title"),
            message: L10n.tr("inbox.empty.description"),
            actionTitle: L10n.tr("inbox.send_test"),
            style: .default
        )
        es.isHidden = true
        return es
    }()

    private let fabButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(LucideIcon.plus.image(pointSize: 24, weight: .semibold), for: .normal)
        button.backgroundColor = ThemeTokens.Color.primary
        button.tintColor = ThemeTokens.Color.text
        button.layer.cornerRadius = ThemeTokens.CornerRadius.pill
        let shadow = ThemeTokens.Shadows.floatingAction
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        button.layer.shadowRadius = shadow.radius
        button.layer.shadowOpacity = Float(shadow.opacity)
        button.accessibilityLabel = L10n.tr("inbox.test.send")
        return button
    }()

    private let swipeHintLabel: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        let iconView = UIImageView()
        iconView.image = LucideIcon.info.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs)
        iconView.tintColor = ThemeTokens.Color.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.accessibilityLabel = "提示信息"
        let label = UILabel()
        label.text = L10n.tr("inbox.swipe.hint")
        label.font = ThemeTokens.Typography.tabLabel
        label.textColor = ThemeTokens.Color.textSecondary
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        stack.alignment = .center
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.xs)
        }
        container.snp.makeConstraints { make in
            make.height.equalTo(30)
        }
        return container
    }()

    private let markAllReadRelay = PublishRelay<Void>()
    private let sendTestRelay = PublishRelay<Void>()
    private let deleteItemRelay = PublishRelay<IndexPath>()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshData()
    }

    override func makeUI() {
        view.backgroundColor = ThemeTokens.Color.background
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

        let clearAllBtn = UIBarButtonItem(
            title: L10n.tr("inbox.clear_all"),
            style: .plain,
            target: nil,
            action: nil
        )
        clearAllBtn.tintColor = ThemeTokens.Color.error
        clearAllBtn.setTitleTextAttributes([.font: ThemeTokens.Typography.metadata], for: .normal)
        navigationItem.rightBarButtonItem = clearAllBtn

        setupScaffold()
        setupFilterPills()

        tableView.refreshControl = refreshControl

        view.addSubview(scaffold)
        view.addSubview(fabButton)
        view.addSubview(swipeHintLabel)

        scaffold.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(swipeHintLabel.snp.top)
        }

        fabButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-ThemeTokens.Spacing.xl)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-ThemeTokens.Spacing.xl)
            make.width.height.equalTo(56)
        }

        swipeHintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-ThemeTokens.Spacing.sm)
        }

        fabButton.addTarget(self, action: #selector(fabHaptic), for: .touchUpInside)

        emptyState.onActionTapped = { [weak self] in
            self?.sendTestRelay.accept(())
        }
    }

    private func setupScaffold() {
        scaffold.addSection(titleLabel)
        scaffold.addSection(searchField, spacing: ThemeTokens.Spacing.md)

        filterScrollView.addSubview(filterStack)
        filterStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
        filterScrollView.snp.makeConstraints { make in
            make.height.equalTo(ThemeTokens.ComponentContract.FilterPill.height)
        }
        scaffold.addSection(filterScrollView, spacing: ThemeTokens.Spacing.sm)

        let tableContainer = UIView()
        tableContainer.addSubview(tableView)
        tableContainer.addSubview(emptyState)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyState.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xxl)
        }
        scaffold.addSection(tableContainer, spacing: ThemeTokens.Spacing.sm)
    }

    @objc private func fabHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func handleRefresh() {
        viewModel.refreshData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    private func setupFilterPills() {
        let filters: [(String, InboxViewModel.FilterType)] = [
            (L10n.tr("inbox.filter.all"), .all),
            (L10n.tr("inbox.filter.unread"), .unread),
            (L10n.tr("inbox.filter.apps"), .apps)
        ]

        for (title, type) in filters {
            let pill = WBKFilterPill(title: title)
            pill.isSelected = type == .all
            pill.onTap = { [weak self] _ in
                guard let self = self else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                let selectedFilter = type
                self.filterRelay.accept(selectedFilter)
                self.updateFilterSelection(selectedFilter)
                self.viewModel.refreshData()
            }
            pill.accessibilityIdentifier = "filter_\(type.rawValue)"
            filterStack.addArrangedSubview(pill)
            filterPills.append(pill)
        }
    }

    private func updateFilterSelection(_ selected: InboxViewModel.FilterType) {
        for (index, pill) in filterPills.enumerated() {
            let filterType = InboxViewModel.FilterType(rawValue: index) ?? .all
            pill.isSelected = filterType == selected
        }
    }

    override func bindViewModel() {
        let markAllRead = navigationItem.rightBarButtonItem!.rx.tap.asDriver(onErrorDriveWith: .empty())

        let input = InboxViewModel.Input(
            refresh: Driver.merge(
                rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () }.asDriver(onErrorJustReturn: ())
            ),
            searchTextChanged: searchField.textField.rx.text.orEmpty.asDriver(onErrorJustReturn: ""),
            filterSelected: filterRelay.asDriver(onErrorJustReturn: .all),
            itemSelect: tableView.rx.itemSelected.asDriver(onErrorDriveWith: .empty()),
            deleteItem: deleteItemRelay.asDriver(onErrorJustReturn: IndexPath(row: 0, section: 0)),
            markAllRead: markAllRead,
            sendTestNotification: fabButton.rx.tap.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.transform(input: input)

        output.reloadData
            .drive(onNext: { [weak self] in
                self?.tableView.reloadData()
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                guard let self = self else { return }
                self.emptyState.isHidden = !isEmpty
                self.tableView.isHidden = isEmpty
            })
            .disposed(by: rx)

        output.selectedMessage
            .drive(onNext: { [weak self] message in
                self?.navigateToDetail(message)
            })
            .disposed(by: rx)
    }

    private func navigateToDetail(_ message: StoredMessage) {
        let detailVC = MessageDetailViewController(message: message)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension InboxViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfGroups()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInGroup(section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = viewModel.messageAt(indexPath)
        let cell = tableView.dequeueReusableCell(
            withIdentifier: InboxMessageCellWrapper.identifier,
            for: indexPath
        ) as! InboxMessageCellWrapper
        cell.configure(with: message)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableCell(
            withIdentifier: InboxGroupHeaderCell.identifier
        ) as! InboxGroupHeaderCell
        header.configure(
            title: viewModel.groupHeaderTitle(section),
            count: viewModel.numberOfRowsInGroup(section),
            isExpanded: viewModel.isGroupExpanded(section),
            hasUnread: viewModel.groupHasUnread(section)
        )
        header.onTap = { [weak self] in
            guard let self = self else { return }
            self.viewModel.toggleGroup(section)
            let isExpanded = self.viewModel.isGroupExpanded(section)
            let rowsInGroup = self.viewModel.numberOfRowsInGroup(section)
            if isExpanded {
                var indexPaths: [IndexPath] = []
                for row in 0..<rowsInGroup {
                    indexPaths.append(IndexPath(row: row, section: section))
                }
                self.tableView.insertRows(at: indexPaths, with: .automatic)
            } else {
                var indexPaths: [IndexPath] = []
                for row in 0..<rowsInGroup {
                    indexPaths.append(IndexPath(row: row, section: section))
                }
                self.tableView.deleteRows(at: indexPaths, with: .automatic)
            }
            self.tableView.reloadSections(IndexSet(integer: section), with: .none)
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
}

// MARK: - UITableViewDelegate

extension InboxViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: L10n.tr("common.delete")) { [weak self] _, _, completion in
            guard let self = self else { return }
            self.deleteItemRelay.accept(indexPath)
            completion(true)
        }
        deleteAction.backgroundColor = ThemeTokens.Color.error
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
