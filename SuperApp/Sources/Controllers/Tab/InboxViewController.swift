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

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(InboxMessageCell.self, forCellReuseIdentifier: InboxMessageCell.identifier)
        table.register(InboxGroupHeaderCell.self, forCellReuseIdentifier: InboxGroupHeaderCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 100
        table.backgroundColor = ThemeColors.current.background
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.contentInset = .zero
        return table
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    private let searchBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        let shadow = ThemeTokens.Shadows.Card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        return view
    }()

    private let searchIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.search.image(pointSize: 16)
        iv.tintColor = ThemeColors.current.textSecondary
        iv.contentMode = .scaleAspectFit
        iv.accessibilityLabel = "搜索"
        return iv
    }()

    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.font = ThemeTokens.Typography.footnote
        tf.textColor = ThemeColors.current.text
        tf.returnKeyType = .search
        tf.attributedPlaceholder = NSAttributedString(
            string: L10n.tr("inbox.search.placeholder"),
            attributes: [.foregroundColor: ThemeColors.current.textSecondary]
        )
        return tf
    }()

    private let filterStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        return stack
    }()

    private var filterButtons: [UIButton] = []
    private let filterRelay = BehaviorRelay<InboxViewModel.FilterType>(value: .all)

    private let emptyStateView: InboxEmptyStateView = {
        let view = InboxEmptyStateView()
        view.isHidden = true
        return view
    }()

    private let fabButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(LucideIcon.send.image(pointSize: 16, weight: .semibold), for: .normal)
        button.setTitle(L10n.tr("inbox.send_test"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.footnote
        button.backgroundColor = ThemeTokens.Color.primary
        button.tintColor = ThemeTokens.Color.text
        button.layer.cornerRadius = ThemeTokens.CornerRadius.full
        let shadow = ThemeTokens.Shadows.Fab
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        button.layer.shadowRadius = shadow.radius
        button.layer.shadowOpacity = Float(shadow.opacity)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        button.accessibilityLabel = "发送测试通知"
        return button
    }()

    private let markAllReadRelay = PublishRelay<Void>()
    private let sendTestRelay = PublishRelay<Void>()

    private let swipeHintLabel: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        let iconView = UIImageView()
        iconView.image = LucideIcon.info.templateImage(pointSize: 12)
        iconView.tintColor = ThemeTokens.Color.textTertiary
        iconView.contentMode = .scaleAspectFit
        iconView.accessibilityLabel = "提示信息"
        let label = UILabel()
        label.text = L10n.tr("inbox.swipe.hint")
        label.font = ThemeTokens.Typography.caption2
        label.textColor = ThemeTokens.Color.textTertiary
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        stack.alignment = .center
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(12)
        }
        container.snp.makeConstraints { make in
            make.height.equalTo(30)
        }
        return container
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshData()
    }

    override func makeUI() {
        view.backgroundColor = ThemeColors.current.background
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

        let clearAllBtn = UIBarButtonItem(
            title: L10n.tr("inbox.clear_all"),
            style: .plain,
            target: nil,
            action: nil
        )
        clearAllBtn.tintColor = ThemeTokens.Color.error
        clearAllBtn.setTitleTextAttributes([.font: ThemeTokens.Typography.footnote], for: .normal)
        navigationItem.rightBarButtonItem = clearAllBtn

        setupFilterPills()

        tableView.refreshControl = refreshControl

        view.addSubview(searchBarContainer)
        searchBarContainer.addSubview(searchIconImageView)
        searchBarContainer.addSubview(searchTextField)
        view.addSubview(filterStackView)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(fabButton)
        view.addSubview(swipeHintLabel)

        searchBarContainer.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(36)
        }

        searchIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        searchTextField.snp.makeConstraints { make in
            make.leading.equalTo(searchIconImageView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }

        filterStackView.snp.makeConstraints { make in
            make.top.equalTo(searchBarContainer.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            make.height.greaterThanOrEqualTo(28)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(filterStackView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(swipeHintLabel.snp.top)
        }

        swipeHintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        fabButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(50)
        }

        emptyStateView.configure(
            iconName: "tray",
            title: L10n.tr("inbox.empty.title"),
            subtitle: L10n.tr("inbox.empty.description")
        )

        fabButton.addTarget(self, action: #selector(fabHaptic), for: .touchUpInside)
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

        let inactiveBg = ThemeTokens.Color.surface
        let inactiveFg = ThemeColors.current.textSecondary
        let activeBg = ThemeTokens.Color.primary
        let activeFg = ThemeTokens.Color.text

        for (title, type) in filters {
            let button: UIButton
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = inactiveBg
                config.baseForegroundColor = inactiveFg
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = ThemeTokens.Typography.footnote
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
                button = UIButton(configuration: config)
            } else {
                button = UIButton(type: .system)
                button.titleLabel?.font = ThemeTokens.Typography.footnote
                button.backgroundColor = inactiveBg
                button.setTitleColor(inactiveFg, for: .normal)
                button.layer.cornerRadius = ThemeTokens.CornerRadius.lg
                button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
            }
            button.setTitle(title, for: .normal)
            button.tag = type.rawValue
            button.accessibilityIdentifier = "filter_\(type.rawValue)"
            button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            filterStackView.addArrangedSubview(button)
            filterButtons.append(button)
        }
        updateFilterSelection(.all)
    }

    @objc private func filterTapped(_ sender: UIButton) {
        guard let filter = InboxViewModel.FilterType(rawValue: sender.tag) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        filterRelay.accept(filter)
        updateFilterSelection(filter)
        viewModel.refreshData()
    }

    private func updateFilterSelection(_ selected: InboxViewModel.FilterType) {
        let inactiveBg = ThemeTokens.Color.surface
        let inactiveFg = ThemeColors.current.textSecondary
        let activeBg = ThemeTokens.Color.primary
        let activeFg = ThemeTokens.Color.text

        for button in filterButtons {
            let isSelected = button.tag == selected.rawValue
            if #available(iOS 15.0, *) {
                var config = button.configuration ?? UIButton.Configuration.filled()
                config.baseBackgroundColor = isSelected ? activeBg : inactiveBg
                config.baseForegroundColor = isSelected ? activeFg : inactiveFg
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = ThemeTokens.Typography.footnote
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
                button.configuration = config
            } else {
                button.backgroundColor = isSelected ? activeBg : inactiveBg
                button.setTitleColor(isSelected ? activeFg : inactiveFg, for: .normal)
            }
        }
    }

    override func bindViewModel() {
        let markAllRead = navigationItem.rightBarButtonItem!.rx.tap.asDriver(onErrorDriveWith: .empty())

        let input = InboxViewModel.Input(
            refresh: Driver.merge(
                rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () }.asDriver(onErrorJustReturn: ())
            ),
            searchTextChanged: searchTextField.rx.text.orEmpty.asDriver(onErrorJustReturn: ""),
            filterSelected: filterRelay.asDriver(onErrorJustReturn: .all),
            itemSelect: tableView.rx.itemSelected.asDriver(onErrorDriveWith: .empty()),
            deleteItem: PublishRelay<IndexPath>().asDriver(onErrorJustReturn: IndexPath(row: 0, section: 0)),
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
                self.emptyStateView.isHidden = !isEmpty
                self.tableView.isHidden = isEmpty
                if !isEmpty {
                    self.view.bringSubviewToFront(self.tableView)
                }
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
            withIdentifier: InboxMessageCell.identifier,
            for: indexPath
        ) as! InboxMessageCell
        cell.configure(with: message)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableCell(
            withIdentifier: InboxGroupHeaderCell.identifier
        ) as! InboxGroupHeaderCell
        header.configure(
            title: viewModel.groupHeaderTitle(section),
            isExpanded: viewModel.isGroupExpanded(section),
            hasUnread: viewModel.groupHasUnread(section)
        )
        header.onTap = { [weak self] in
            guard let self = self else { return }
            let wasExpanded = self.viewModel.isGroupExpanded(section)
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
            let message = self.viewModel.messageAt(indexPath)
            Task {
                await MessageEngine.shared.deleteMessage(id: message.id)
                self.viewModel.refreshData()
                completion(true)
            }
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
