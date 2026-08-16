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

    /// 横幅点击时暂存的待定位消息（仅主线程读写）。冷启动时本页可能
    /// 尚未完成订阅绑定，定位通知会丢；收件箱就绪后主动消费该待办。
    static var pendingFocus: (title: String, body: String)?

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

    private lazy var reviewButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("review.entry"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.metadata
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        button.contentEdgeInsets = .zero
        button.accessibilityIdentifier = "inbox.review.entry"
        button.addTarget(self, action: #selector(openReview), for: .touchUpInside)
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
        table.register(InboxGroupHeaderCell.self, forHeaderFooterViewReuseIdentifier: InboxGroupHeaderCell.identifier)
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

    /// Guards against overlapping group toggle animations; this screen has a
    /// crash history from batch updates racing each other.
    private var isAnimatingGroupToggle = false
    /// Marks the next reload as an animated display-mode transition.
    private var pendingAnimatedReload = false
    /// Header whose swipe actions are currently revealed; opening another
    /// closes this one first.
    private weak var openSwipeHeader: InboxGroupHeaderCell?

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
        header.addSubview(reviewButton)
        header.addSubview(clearAllButton)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(reviewButton.snp.leading).offset(-ThemeTokens.Spacing.md)
        }
        reviewButton.snp.makeConstraints { make in
            make.trailing.equalTo(clearAllButton.snp.leading).offset(-ThemeTokens.Spacing.md)
            make.centerY.equalToSuperview()
            make.height.greaterThanOrEqualTo(32)
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

    /// Opens the card-stack triage flow over the current inbox order,
    /// starting at the first unread message.
    @objc private func openReview() {
        let ordered = viewModel.orderedMessages()
        let unread = ordered.filter { !$0.isRead }
        guard !unread.isEmpty, let firstIndex = ordered.firstIndex(where: { $0.id == unread[0].id }) else {
            reviewButton.isEnabled = false
            return
        }
        reviewButton.isEnabled = true
        let queue = Array(ordered[firstIndex...])
        navigationController?.pushViewController(MessageReviewViewController(messages: queue), animated: true)
    }

    @objc private func displayModeChanged() {
        guard let mode = InboxViewModel.DisplayMode(rawValue: displayModeControl.selectedSegmentIndex) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        pendingAnimatedReload = true
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
                guard let self = self else { return }
                self.isAnimatingGroupToggle = false
                if self.pendingAnimatedReload {
                    self.pendingAnimatedReload = false
                    UIView.transition(
                        with: self.tableView,
                        duration: ThemeTokens.Animation.normal.duration,
                        options: [.transitionCrossDissolve, .allowUserInteraction],
                        animations: { self.tableView.reloadData() }
                    )
                } else {
                    self.tableView.reloadData()
                }
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                guard let self = self else { return }
                self.emptyState.isHidden = !isEmpty
                self.tableView.isHidden = isEmpty
            })
            .disposed(by: rx)

        output.unreadCount
            .drive(onNext: { [weak self] count in
                guard let self = self else { return }
                self.reviewButton.isEnabled = count > 0
                self.reviewButton.alpha = count > 0 ? 1 : 0.4
            })
            .disposed(by: rx)

        output.selectedMessage
            .drive(onNext: { [weak self] message in
                self?.navigateToDetail(message)
            })
            .disposed(by: rx)

        // 横幅点击（无显式路由的推送）会切到本页并请求定位到对应消息
        NotificationCenter.default.rx.notification(.focusInboxMessage)
            .subscribe(onNext: { [weak self] notification in
                // 热路径直接处理，同时清掉待办避免冷路径重复消费
                Self.pendingFocus = nil
                let title = notification.userInfo?["title"] as? String
                let body = notification.userInfo?["body"] as? String
                // 点击路径同时会写入消息，稍等一拍再定位；找不到再补一次
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard let self, !self.focusMessage(title: title, body: body) else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        self.focusMessage(title: title, body: body)
                    }
                }
            })
            .disposed(by: rx)

        // 冷启动：本页刚加载完，消费横幅点击留下的待定位消息
        consumePendingFocusIfAny()
    }

    /// 消费 PushRouter 暂存的待定位消息；带重试以等待消息入库。
    private func consumePendingFocusIfAny() {
        guard let pending = Self.pendingFocus else { return }
        Self.pendingFocus = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            if !self.focusMessage(title: pending.title, body: pending.body) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                    self?.focusMessage(title: pending.title, body: pending.body)
                }
            }
        }
    }

    /// 在当前过滤视图里查找并打开对应消息；返回是否找到。
    @discardableResult
    private func focusMessage(title: String?, body: String?) -> Bool {
        guard let title else { return false }
        for section in 0..<viewModel.numberOfGroups() {
            for row in 0..<viewModel.numberOfRowsInGroup(section) {
                let message = viewModel.messageAt(IndexPath(row: row, section: section))
                if message.payload.title == title && (body == nil || message.payload.body == body) {
                    navigateToDetail(message)
                    return true
                }
            }
        }
        return false
    }

    private func navigateToDetail(_ message: StoredMessage) {
        navigationController?.setNavigationBarHidden(false, animated: true)
        let detailVC = MessageDetailViewController(message: message, peerMessages: viewModel.orderedMessages())
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
        // Collapsed-group rows persist at zero height with their accessibility
        // identity stripped until revealed again.
        cell.setCollapsedAccessibility(!viewModel.isRowRevealed(at: indexPath))
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard viewModel.showsGroupHeaders else { return 92 }
        return viewModel.isRowRevealed(at: indexPath) ? 92 : 0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard viewModel.showsGroupHeaders else { return nil }
        // Dequeue via the header/footer API: a plain cell used as a header
        // view desynchronizes from UIKit's header management under
        // beginUpdates/endUpdates and all other sections' headers vanish.
        guard let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: InboxGroupHeaderCell.identifier
        ) as? InboxGroupHeaderCell else { return nil }
        let configureHeader = { [weak self] (isExpanded: Bool, count: Int) in
            guard let self = self else { return }
            header.configure(
                title: self.viewModel.groupHeaderTitle(section),
                count: count,
                isExpanded: isExpanded,
                hasUnread: self.viewModel.groupHasUnread(section),
                isPinned: self.viewModel.isGroupPinned(section),
                accessibilityIdentifier: "notification.group.\(self.viewModel.groupIdentifier(section).slugIdentifier)"
            )
        }
        configureHeader(viewModel.isGroupExpanded(section), viewModel.numberOfMessagesInGroup(section))
        header.onTap = { [weak self] in
            guard let self = self, !self.isAnimatingGroupToggle else { return }
            self.toggleGroupAnimated(section: section, configureHeader: configureHeader)
        }
        header.onPinToggle = { [weak self] in
            self?.viewModel.togglePinGroup(section)
        }
        header.onDelete = { [weak self] in
            self?.confirmDeleteGroup(section)
        }
        header.onSwipeReveal = { [weak self, weak header] in
            guard let self = self else { return }
            if let open = self.openSwipeHeader, open !== header {
                open.closeActions(animated: true)
            }
            self.openSwipeHeader = header
        }
        return header
    }

    /// Group deletion is a bulk destructive action; confirm before wiping
    /// every message in the section.
    private func confirmDeleteGroup(_ section: Int) {
        let title = viewModel.groupHeaderTitle(section)
        let count = viewModel.numberOfMessagesInGroup(section)
        let alert = UIAlertController(
            title: L10n.tr("inbox.group.delete.title"),
            message: L10n.tr("inbox.group.delete.message", title, count),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("inbox.group.delete.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(
            title: L10n.tr("inbox.group.delete.confirm"),
            style: .destructive
        ) { [weak self] _ in
            self?.viewModel.deleteGroup(section)
        })
        present(alert, animated: true)
    }

    /// Height-morph accordion: collapsed rows stay in the table and collapse to
    /// zero height, so the compress-away of the group and the slide-up of the
    /// sections below happen in one continuous system-driven animation.
    private func toggleGroupAnimated(section: Int, configureHeader: (Bool, Int) -> Void) {
        let messageCount = viewModel.numberOfMessagesInGroup(section)
        let indexPaths = (0..<messageCount).map { IndexPath(row: $0, section: section) }
        let willExpand = !viewModel.isGroupExpanded(section)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        isAnimatingGroupToggle = true
        // Capture cells before the toggle: once heights reach zero,
        // `cellForRow` returns nil for those index paths.
        let cells = indexPaths.compactMap { tableView.cellForRow(at: $0) as? InboxMessageCellWrapper }
        configureHeader(willExpand, messageCount)
        viewModel.toggleGroup(section)
        // Classic accordion idiom: begin/endUpdates animates the row-height
        // change and the displacement of everything below it. An empty
        // performBatchUpdates skips the animated path entirely when invoked
        // outside a touch-driven runloop turn (the UI-test hook), producing a
        // single-frame snap and a completion that never fires — which would
        // deadlock the toggle mutex. CATransaction carries the completion.
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self else { return }
            if willExpand {
                // Heights are full again, so cellForRow resolves; restore
                // identity for cells that stayed cached through the
                // collapsed state (cellForRowAt never re-ran for them).
                indexPaths.forEach {
                    (self.tableView.cellForRow(at: $0) as? InboxMessageCellWrapper)?
                        .setCollapsedAccessibility(false)
                }
            } else {
                // Strip identity only after the compression finished so the
                // cards stay exposed to accessibility while they animate.
                cells.forEach { $0.setCollapsedAccessibility(true) }
            }
            self.isAnimatingGroupToggle = false
        }
        tableView.beginUpdates()
        tableView.endUpdates()
        CATransaction.commit()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Compact 36pt header: at 44pt the small title floated with ~14pt of
        // dead space above and below it, which read as oversized inter-group
        // gaps next to the 8pt spacing between cards inside a group.
        return viewModel.showsGroupHeaders ? 36 : .leastNormalMagnitude
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
