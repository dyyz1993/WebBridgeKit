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
        label.font = ThemeTokens.Typography.compactTitle
        label.textColor = ThemeTokens.Color.text
        label.text = L10n.tr("tab.inbox")
        label.numberOfLines = 1
        return label
    }()

    private let clearAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("inbox.mark_all_read"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.metadata
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        button.contentEdgeInsets = .zero
        return button
    }()

    private let searchField = WBKSearchField(placeholder: L10n.tr("inbox.search.placeholder"))

    private let displayModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            L10n.tr("inbox.display.latest"),
            L10n.tr("inbox.display.groups")
        ])
        control.selectedSegmentIndex = InboxViewModel.DisplayMode.latest.rawValue
        control.selectedSegmentTintColor = ThemeTokens.Color.surface
        control.backgroundColor = ThemeTokens.Color.backgroundSecondary
        control.setTitleTextAttributes([
            .font: ThemeTokens.Typography.metadata,
            .foregroundColor: ThemeTokens.Color.textSecondary
        ], for: .normal)
        control.setTitleTextAttributes([
            .font: ThemeTokens.Typography.metadata,
            .foregroundColor: ThemeTokens.Color.primary
        ], for: .selected)
        control.accessibilityIdentifier = "inbox.displayMode"
        return control
    }()

    private let filterStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()

    private let filterScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.accessibilityIdentifier = "inbox.filters"
        return scrollView
    }()

    private var filterButtons: [UIButton] = []
    private let filterRelay = BehaviorRelay<InboxViewModel.FilterType>(value: .all)

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(InboxMessageCellWrapper.self, forCellReuseIdentifier: InboxMessageCellWrapper.identifier)
        table.register(InboxGroupHeaderCell.self, forCellReuseIdentifier: InboxGroupHeaderCell.identifier)
        // A notification preview has a fixed, scannable shape; details belong in its detail screen.
        table.rowHeight = 92
        table.estimatedRowHeight = 92
        table.backgroundColor = ThemeTokens.Color.background
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.contentInset = .zero
        table.contentInsetAdjustmentBehavior = .never
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
            actionTitle: nil,
            style: .default
        )
        es.isHidden = true
        return es
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
    private let deleteItemRelay = PublishRelay<IndexPath>()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.refreshData()
    }

    override func makeUI() {
        view.backgroundColor = ThemeTokens.Color.background
        view.accessibilityIdentifier = "InboxViewController"
        setupFilterPills()
        setupScaffold()
        displayModeControl.addTarget(self, action: #selector(displayModeChanged), for: .valueChanged)

        tableView.refreshControl = refreshControl

        view.addSubview(scaffold)
        view.addSubview(swipeHintLabel)

        scaffold.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(swipeHintLabel.snp.top)
        }

        swipeHintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-ThemeTokens.Spacing.sm)
        }

    }

    private func setupScaffold() {
        let header = UIView()
        header.addSubview(titleLabel)
        header.addSubview(clearAllButton)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(clearAllButton.snp.leading).offset(-ThemeTokens.Spacing.md)
        }
        clearAllButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.height.greaterThanOrEqualTo(32)
        }
        header.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        scaffold.addSection(header)
        displayModeControl.snp.makeConstraints { make in
            make.height.equalTo(32)
        }
        scaffold.addSection(displayModeControl, spacing: ThemeTokens.Spacing.sm)
        scaffold.addSection(searchField, spacing: ThemeTokens.Spacing.md)

        filterScrollView.addSubview(filterStack)
        filterStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(ThemeTokens.ComponentContract.FilterPill.height)
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

    @objc private func handleRefresh() {
        viewModel.refreshData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    @objc private func displayModeChanged() {
        guard let mode = InboxViewModel.DisplayMode(rawValue: displayModeControl.selectedSegmentIndex) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        viewModel.setDisplayMode(mode)
    }

    private func setupFilterPills() {
        let filters: [(String, InboxViewModel.FilterType)] = [
            (L10n.tr("inbox.filter.all"), .all),
            (L10n.tr("inbox.filter.unread"), .unread),
            (L10n.tr("inbox.filter.apps"), .apps),
            (L10n.tr("inbox.filter.action_required"), .actionRequired)
        ]

        for (title, type) in filters {
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = ThemeTokens.Typography.caption
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: ThemeTokens.Spacing.md,
                bottom: 0,
                right: ThemeTokens.Spacing.md
            )
            button.layer.cornerRadius = ThemeTokens.ComponentContract.FilterPill.height / 2
            button.layer.borderWidth = 1
            button.clipsToBounds = true
            button.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                let selectedFilter = type
                self.filterRelay.accept(selectedFilter)
                self.updateFilterSelection(selectedFilter)
                self.viewModel.refreshData()
            }, for: .touchUpInside)
            button.accessibilityIdentifier = type.accessibilityIdentifier
            button.snp.makeConstraints { make in
                make.height.equalTo(ThemeTokens.ComponentContract.FilterPill.height)
                make.width.greaterThanOrEqualTo(ThemeTokens.ComponentContract.FilterPill.minWidth)
            }
            button.setContentHuggingPriority(.required, for: .horizontal)
            filterStack.addArrangedSubview(button)
            filterButtons.append(button)
        }
        updateFilterSelection(.all)
    }

    private func updateFilterSelection(_ selected: InboxViewModel.FilterType) {
        for (index, button) in filterButtons.enumerated() {
            let filterType = InboxViewModel.FilterType(rawValue: index) ?? .all
            let isSelected = filterType == selected
            button.isSelected = isSelected
            button.backgroundColor = isSelected
                ? ThemeTokens.Color.primarySoft
                : ThemeTokens.Color.surface
            button.layer.borderColor = (isSelected
                ? ThemeTokens.Color.primary
                : ThemeTokens.Color.border).cgColor
            button.setTitleColor(
                isSelected ? ThemeTokens.Color.primary : ThemeTokens.Color.textSecondary,
                for: .normal
            )
        }
    }

    override func bindViewModel() {
        let markAllRead = clearAllButton.rx.tap.asDriver(onErrorDriveWith: .empty())

        let input = InboxViewModel.Input(
            refresh: Driver.merge(
                rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () }.asDriver(onErrorJustReturn: ())
            ),
            searchTextChanged: searchField.textField.rx.text.orEmpty.asDriver(onErrorJustReturn: ""),
            filterSelected: filterRelay.asDriver(onErrorJustReturn: .all),
            itemSelect: tableView.rx.itemSelected.asDriver(onErrorDriveWith: .empty()),
            deleteItem: deleteItemRelay.asDriver(onErrorJustReturn: IndexPath(row: 0, section: 0)),
            markAllRead: markAllRead,
            sendTestNotification: Driver<Void>.empty()
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
        navigationController?.setNavigationBarHidden(false, animated: true)
        let detailVC = MessageDetailViewController(message: message)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

private extension InboxViewModel.FilterType {
    var accessibilityIdentifier: String {
        switch self {
        case .all: return "filter_all"
        case .unread: return "filter_unread"
        case .apps: return "filter_apps"
        case .actionRequired: return "filter_action_required"
        }
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
        guard viewModel.showsGroupHeaders else { return nil }
        let header = tableView.dequeueReusableCell(
            withIdentifier: InboxGroupHeaderCell.identifier
        ) as! InboxGroupHeaderCell
        header.configure(
            title: viewModel.groupHeaderTitle(section),
            count: viewModel.numberOfMessagesInGroup(section),
            isExpanded: viewModel.isGroupExpanded(section),
            hasUnread: viewModel.groupHasUnread(section),
            accessibilityIdentifier: "notification.group.\(viewModel.groupIdentifier(section).slugIdentifier)"
        )
        header.onTap = { [weak self] in
            guard let self = self else { return }
            let messageCount = self.viewModel.numberOfMessagesInGroup(section)
            self.viewModel.toggleGroup(section)
            let isExpanded = self.viewModel.isGroupExpanded(section)
            let indexPaths = (0..<messageCount).map { IndexPath(row: $0, section: section) }
            self.tableView.performBatchUpdates {
                if isExpanded {
                    self.tableView.insertRows(at: indexPaths, with: .automatic)
                } else {
                    self.tableView.deleteRows(at: indexPaths, with: .automatic)
                }
            }
            header.configure(
                title: self.viewModel.groupHeaderTitle(section),
                count: messageCount,
                isExpanded: isExpanded,
                hasUnread: self.viewModel.groupHasUnread(section),
                accessibilityIdentifier: "notification.group.\(self.viewModel.groupIdentifier(section).slugIdentifier)"
            )
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.showsGroupHeaders ? 44 : .leastNormalMagnitude
    }
}

private extension String {
    var slugIdentifier: String {
        lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
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
