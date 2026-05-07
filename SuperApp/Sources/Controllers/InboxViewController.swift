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
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(InboxMessageCell.self, forCellReuseIdentifier: InboxMessageCell.identifier)
        table.register(InboxGroupHeaderCell.self, forCellReuseIdentifier: InboxGroupHeaderCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.backgroundColor = .systemGroupedBackground
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        return table
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    private let searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = L10n.tr("inbox.search.placeholder")
        return sc
    }()

    private let filterStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()

    private var filterButtons: [UIButton] = []
    private let filterRelay = BehaviorRelay<InboxViewModel.FilterType>(value: .all)

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private let fabButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(LucideIcon.bell.image(pointSize: 22, weight: .semibold), for: .normal)
        button.backgroundColor = ThemeColors.current.fabBackground
        button.tintColor = .white
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.3
        return button
    }()

    private let markAllReadRelay = PublishRelay<Void>()
    private let sendTestRelay = PublishRelay<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("inbox.title")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshData()
    }

    override func makeUI() {
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: LucideIcon.check.image(pointSize: 20),
            style: .plain,
            target: nil,
            action: nil
        )

        setupFilterPills()

        tableView.refreshControl = refreshControl

        view.addSubview(filterStackView)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(fabButton)

        filterStackView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            make.height.greaterThanOrEqualTo(36)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(filterStackView.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        fabButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.width.height.equalTo(56)
        }

        emptyStateView.configure(
            icon: "tray",
            title: L10n.tr("inbox.empty.title"),
            description: L10n.tr("inbox.empty.description"),
            actionTitle: nil
        )
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
            (L10n.tr("inbox.filter.today"), .today)
        ]

        for (title, type) in filters {
            let button: UIButton
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = .secondarySystemFill
                config.baseForegroundColor = .secondaryLabel
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = .systemFont(ofSize: 13, weight: .medium)
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                button = UIButton(configuration: config)
            } else {
                button = UIButton(type: .system)
                button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
                button.backgroundColor = .secondarySystemFill
                button.layer.cornerRadius = 16
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            }
            button.setTitle(title, for: .normal)
            button.tag = type.rawValue
            button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            filterStackView.addArrangedSubview(button)
            filterButtons.append(button)
        }
        updateFilterSelection(.all)
    }

    @objc private func filterTapped(_ sender: UIButton) {
        guard let filter = InboxViewModel.FilterType(rawValue: sender.tag) else { return }
        filterRelay.accept(filter)
        updateFilterSelection(filter)
        viewModel.refreshData()
    }

    private func updateFilterSelection(_ selected: InboxViewModel.FilterType) {
        for button in filterButtons {
            let isSelected = button.tag == selected.rawValue
            if #available(iOS 15.0, *) {
                var config = button.configuration ?? UIButton.Configuration.filled()
                config.baseBackgroundColor = isSelected ? ThemeColors.current.primary : .secondarySystemFill
                config.baseForegroundColor = isSelected ? .white : .secondaryLabel
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = .systemFont(ofSize: 13, weight: .medium)
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                button.configuration = config
            } else {
                button.backgroundColor = isSelected ? ThemeColors.current.primary : .secondarySystemFill
                button.setTitleColor(isSelected ? .white : .secondaryLabel, for: .normal)
            }
        }
    }

    override func bindViewModel() {
        let markAllRead = navigationItem.rightBarButtonItem!.rx.tap.asDriver(onErrorDriveWith: .empty())

        let input = InboxViewModel.Input(
            refresh: Driver.merge(
                rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () }.asDriver(onErrorJustReturn: ())
            ),
            searchTextChanged: searchController.searchBar.rx.text.orEmpty.asDriver(onErrorJustReturn: ""),
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
        if message.payload.hasRoute {
            if let urlString = message.payload.targetURL, let url = URL(string: urlString) {
                let params = WebBrowserParams(payload: message.payload.userInfo)
                WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
                return
            }
            if let appId = message.payload.targetAppId {
                if let result = ManifestStore.shared.getManifestByAppId(appId),
                   let url = URL(string: result.key) {
                    let params = WebBrowserParams(payload: message.payload.userInfo)
                    WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
                    return
                }
            }
        }
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
            isExpanded: viewModel.isGroupExpanded(section)
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

// MARK: - InboxGroupHeaderCell

class InboxGroupHeaderCell: UITableViewCell {

    static let identifier = "InboxGroupHeaderCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "chevron.down")
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)

        contentView.addSubview(titleLabel)
        contentView.addSubview(chevronImageView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    func configure(title: String, isExpanded: Bool) {
        titleLabel.text = title
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        chevronImageView.image = UIImage(systemName: imageName)
    }

    @objc private func handleTap() {
        onTap?()
    }
}

// MARK: - InboxMessageCell

class InboxMessageCell: UITableViewCell {

    static let identifier = "InboxMessageCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = 12
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let unreadDot: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.primary
        view.layer.cornerRadius = 5
        view.isHidden = true
        return view
    }()

    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = ThemeColors.current.primary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.addSubview(unreadDot)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(sourceLabel)

        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.leading.equalToSuperview().offset(0)
            make.trailing.equalToSuperview().offset(0)
        }

        unreadDot.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(12)
            make.width.height.equalTo(10)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(unreadDot.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-12)
        }

        sourceLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
        }

        timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(sourceLabel)
            make.trailing.equalToSuperview().offset(-12)
        }

        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(sourceLabel.snp.bottom).offset(6)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    func configure(with message: StoredMessage) {
        titleLabel.text = message.payload.title
        bodyLabel.text = message.payload.body
        unreadDot.isHidden = message.isRead
        titleLabel.font = message.isRead
            ? .systemFont(ofSize: 16, weight: .regular)
            : .systemFont(ofSize: 16, weight: .bold)

        sourceLabel.text = message.payload.channel.uppercased()

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        timeLabel.text = formatter.string(from: message.receivedAt)
    }
}
