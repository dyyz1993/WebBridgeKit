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
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.06
        return view
    }()

    private let searchIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.search.image(pointSize: 16)
        iv.tintColor = ThemeColors.current.textSecondary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.font = .systemFont(ofSize: 14)
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
        stack.spacing = 8
        stack.distribution = .fill
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
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.backgroundColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.30
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        return button
    }()

    private let markAllReadRelay = PublishRelay<Void>()
    private let sendTestRelay = PublishRelay<Void>()

    private let swipeHintLabel: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        let iconView = UIImageView()
        iconView.image = LucideIcon.info.templateImage(pointSize: 12)
        iconView.tintColor = ThemeTokens.Colors.Light.textTertiary
        iconView.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = L10n.tr("inbox.swipe.hint")
        label.font = .systemFont(ofSize: 11)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 6
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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("inbox.title")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshData()
    }

    override func makeUI() {
        view.backgroundColor = ThemeColors.current.background
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        let clearAllBtn = UIBarButtonItem(
            title: L10n.tr("inbox.clear_all"),
            style: .plain,
            target: nil,
            action: nil
        )
        clearAllBtn.tintColor = ThemeTokens.Colors.Light.error
        clearAllBtn.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .normal)
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

        let inactiveBg = UIColor(red: 0.898, green: 0.898, blue: 0.918, alpha: 1.0)
        let inactiveFg = ThemeColors.current.textSecondary
        let activeBg = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        let activeFg = UIColor.white

        for (title, type) in filters {
            let button: UIButton
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = inactiveBg
                config.baseForegroundColor = inactiveFg
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFont.systemFont(ofSize: 13, weight: .medium)
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
                button = UIButton(configuration: config)
            } else {
                button = UIButton(type: .system)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
                button.backgroundColor = inactiveBg
                button.setTitleColor(inactiveFg, for: .normal)
                button.layer.cornerRadius = 14
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
        filterRelay.accept(filter)
        updateFilterSelection(filter)
        viewModel.refreshData()
    }

    private func updateFilterSelection(_ selected: InboxViewModel.FilterType) {
        let inactiveBg = UIColor(red: 0.898, green: 0.898, blue: 0.918, alpha: 1.0)
        let inactiveFg = ThemeColors.current.textSecondary
        let activeBg = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        let activeFg = UIColor.white

        for button in filterButtons {
            let isSelected = button.tag == selected.rawValue
            if #available(iOS 15.0, *) {
                var config = button.configuration ?? UIButton.Configuration.filled()
                config.baseBackgroundColor = isSelected ? activeBg : inactiveBg
                config.baseForegroundColor = isSelected ? activeFg : inactiveFg
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFont.systemFont(ofSize: 13, weight: .medium)
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

// MARK: - InboxGroupHeaderCell

class InboxGroupHeaderCell: UITableViewCell {

    static let identifier = "InboxGroupHeaderCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronDown.templateImage(pointSize: 14)
        iv.tintColor = ThemeColors.current.textSecondary
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
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
    }

    func configure(title: String, isExpanded: Bool, hasUnread: Bool = false) {
        titleLabel.text = title
        chevronImageView.image = isExpanded
            ? LucideIcon.chevronDown.templateImage(pointSize: 14)
            : LucideIcon.chevronRight.templateImage(pointSize: 14)
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
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.06
        return view
    }()

    private let typeIconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()

    private let typeIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        return iv
    }()

    private let unreadDot: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
        view.layer.cornerRadius = 5
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let sourceContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()

    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.numberOfLines = 1
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = ThemeColors.current.textSecondary
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 2
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronRight.image(pointSize: 16, weight: .medium)
        iv.tintColor = ThemeTokens.Colors.Light.textTertiary
        iv.contentMode = .scaleAspectFit
        return iv
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
        cardView.addSubview(typeIconContainer)
        typeIconContainer.addSubview(typeIconView)
        cardView.addSubview(unreadDot)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(sourceContainer)
        sourceContainer.addSubview(sourceLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(chevronImageView)

        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().offset(-2)
            make.leading.trailing.equalToSuperview()
        }

        typeIconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(40)
        }

        typeIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        unreadDot.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.width.height.equalTo(10)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(typeIconContainer.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
        }

        bodyLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }

        sourceContainer.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(bodyLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-12)
        }

        sourceLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6))
        }

        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(sourceContainer.snp.trailing).offset(6)
            make.centerY.equalTo(sourceContainer)
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    func configure(with message: StoredMessage) {
        titleLabel.text = message.payload.title
        bodyLabel.text = message.payload.body

        let isUnread = !message.isRead
        titleLabel.font = isUnread
            ? .systemFont(ofSize: 15, weight: .bold)
            : .systemFont(ofSize: 15, weight: .regular)
        unreadDot.alpha = isUnread ? 1 : 0

        let channel = message.payload.channel.uppercased()
        sourceLabel.text = channel

        let primaryColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        let accentColor = UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
        let warningColor = UIColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)
        let grayColor = UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)

        switch channel {
        case "APNS", "APN":
            typeIconContainer.backgroundColor = primaryColor.withAlphaComponent(0.12)
            typeIconView.tintColor = primaryColor
            typeIconView.image = UIImage(lucideId: "package") ?? LucideIcon.appFill.image(pointSize: 20)
            sourceContainer.backgroundColor = primaryColor.withAlphaComponent(0.12)
            sourceLabel.textColor = primaryColor
        case "BARK":
            typeIconContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
            typeIconView.tintColor = accentColor
            typeIconView.image = LucideIcon.link.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
            sourceLabel.textColor = accentColor
        case "BRIDGE":
            typeIconContainer.backgroundColor = warningColor.withAlphaComponent(0.12)
            typeIconView.tintColor = warningColor
            typeIconView.image = LucideIcon.bell.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = warningColor.withAlphaComponent(0.12)
            sourceLabel.textColor = warningColor
        case "SYSTEM", "LOCAL":
            typeIconContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            typeIconView.tintColor = grayColor
            typeIconView.image = LucideIcon.settings.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            sourceLabel.textColor = grayColor
        default:
            typeIconContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            typeIconView.tintColor = grayColor
            typeIconView.image = LucideIcon.settings.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            sourceLabel.textColor = grayColor
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        timeLabel.text = timeFmt.string(from: message.receivedAt)
    }
}

// MARK: - InboxEmptyStateView

class InboxEmptyStateView: UIView {

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(red: 0.780, green: 0.780, blue: 0.800, alpha: 1.0)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = ThemeColors.current.text
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        accessibilityIdentifier = "InboxEmptyStateView"

        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    func configure(iconName: String, title: String, subtitle: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .light)
        iconImageView.image = UIImage(systemName: iconName, withConfiguration: config)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
