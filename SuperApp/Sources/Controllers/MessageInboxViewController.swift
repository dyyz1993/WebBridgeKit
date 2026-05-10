//
//  MessageInboxViewController.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

class MessageInboxViewController: UIViewController {

    private let disposeBag = DisposeBag()
    private let messagesRelay = BehaviorRelay<[StoredMessage]>(value: [])
    private let filterRelay = BehaviorRelay<FilterType>(value: .all)
    private var refreshTimer: Timer?

    enum FilterType: Int {
        case all = 0
        case unread
        case apps
    }

    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [L10n.tr("message.inbox.all"), L10n.tr("message.inbox.unread"), L10n.tr("message.inbox.apps")])
        control.selectedSegmentIndex = 0
        return control
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 100
        table.tableFooterView = UIView()
        table.backgroundColor = ThemeColors.current.background
        return table
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("message.inbox.empty")
        label.textColor = ThemeColors.current.textSecondary
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindData()
        startRefreshing()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshMessages()
        startRefreshing()
    }

    private func startRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshMessages()
        }
    }

    private func refreshMessages() {
        Task {
            let messages = await MessageEngine.shared.getMessages()
            await MainActor.run { [weak self] in
                self?.messagesRelay.accept(messages)
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background
        title = L10n.tr("message.inbox.title")

        navigationItem.titleView = segmentedControl
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.tr("message.inbox.clear_all"), style: .plain, target: self, action: #selector(clearAll))

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
    }

    @objc private func filterChanged() {
        if let filter = FilterType(rawValue: segmentedControl.selectedSegmentIndex) {
            filterRelay.accept(filter)
        }
    }

    private func bindData() {
        let filteredMessages = Observable.combineLatest(messagesRelay, filterRelay)
            .map { messages, filter -> [StoredMessage] in
                switch filter {
                case .all:
                    return messages
                case .unread:
                    return messages.filter { !$0.isRead }
                case .apps:
                    return messages.filter { $0.payload.targetAppId != nil }
                }
            }
            .share(replay: 1)

        filteredMessages
            .bind(to: tableView.rx.items(cellIdentifier: MessageCell.identifier, cellType: MessageCell.self)) { _, message, cell in
                cell.configure(with: message)
            }
            .disposed(by: disposeBag)

        filteredMessages
            .map { !$0.isEmpty }
            .bind(to: emptyLabel.rx.isHidden)
            .disposed(by: disposeBag)

        tableView.rx.modelSelected(StoredMessage.self)
            .subscribe(onNext: { [weak self] message in
                self?.handleMessageClick(message)
            })
            .disposed(by: disposeBag)
    }

    private func handleMessageClick(_ message: StoredMessage) {
        Task {
            await MessageEngine.shared.markAsRead(id: message.id)
            refreshMessages()
        }

        if let urlString = message.payload.targetURL, let url = URL(string: urlString) {
            let params = WebBrowserParams(payload: message.payload.userInfo)
            WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
        } else if let appId = message.payload.targetAppId {
            if let result = ManifestStore.shared.getManifestByAppId(appId),
               let url = URL(string: result.key) {
                let params = WebBrowserParams(payload: message.payload.userInfo)
                WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
            } else {
                if let url = URL(string: appId), url.scheme == "http" || url.scheme == "https" {
                    let params = WebBrowserParams(payload: message.payload.userInfo)
                    WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
                } else {
                    let alert = UIAlertController(title: L10n.tr("message.inbox.cannot_open_app"), message: L10n.tr("message.inbox.app_not_found_format", appId), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }

    @objc private func clearAll() {
        let alert = UIAlertController(title: L10n.tr("message.inbox.confirm_clear_title"), message: L10n.tr("message.inbox.confirm_clear_message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("message.inbox.clear_all"), style: .destructive) { [weak self] _ in
            Task {
                await MessageEngine.shared.clearAllMessages()
                self?.refreshMessages()
            }
        })
        present(alert, animated: true)
    }
}

class MessageCell: UITableViewCell {
    static let identifier = "MessageCell"

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()
    private let sourceBadge = UIView()
    private let sourceLabel = UILabel()
    private let unreadDot = UIView()

    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let actionImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        let cardView = UIView()
        cardView.backgroundColor = ThemeColors.current.cardBackground
        cardView.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        contentView.addSubview(cardView)

        iconContainer.layer.cornerRadius = 10
        iconContainer.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeColors.current.primary

        titleLabel.font = ThemeTokens.Typography.headline
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.font = ThemeTokens.Typography.footnote
        bodyLabel.textColor = ThemeColors.current.textSecondary
        bodyLabel.numberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = ThemeTokens.Typography.caption2
        timeLabel.textColor = ThemeColors.current.textSecondary
        timeLabel.numberOfLines = 1

        sourceBadge.backgroundColor = ThemeColors.current.textSecondary.withAlphaComponent(0.1)
        sourceBadge.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        sourceLabel.font = ThemeTokens.Typography.caption2
        sourceLabel.textColor = ThemeColors.current.textSecondary
        sourceLabel.numberOfLines = 1

        unreadDot.backgroundColor = ThemeColors.current.error
        unreadDot.layer.cornerRadius = ThemeTokens.CornerRadius.sm

        actionImageView.image = UIImage(systemName: "chevron.right")
        actionImageView.tintColor = ThemeColors.current.textSecondary
        actionImageView.contentMode = .scaleAspectFit

        cardView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(sourceBadge)
        sourceBadge.addSubview(sourceLabel)
        cardView.addSubview(unreadDot)
        cardView.addSubview(actionImageView)

        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        iconContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(12)
            make.size.equalTo(40)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }

        unreadDot.snp.makeConstraints { make in
            make.top.equalTo(iconContainer).offset(-2)
            make.trailing.equalTo(iconContainer).offset(2)
            make.size.equalTo(10)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer)
            make.leading.equalTo(iconContainer.snp.trailing).offset(12)
            make.trailing.equalTo(actionImageView.snp.leading).offset(-8)
        }

        actionImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-12)
            make.size.equalTo(16)
        }

        sourceBadge.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.equalTo(titleLabel)
            make.height.equalTo(18)
        }

        sourceLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6))
        }

        timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(sourceBadge)
            make.leading.equalTo(sourceBadge.snp.trailing).offset(8)
        }

        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(sourceBadge.snp.bottom).offset(8)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        bodyLabel.text = nil
        timeLabel.text = nil
        sourceLabel.text = nil
        unreadDot.isHidden = true
        iconImageView.image = nil
        iconContainer.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
        iconImageView.tintColor = ThemeColors.current.primary
        actionImageView.isHidden = true
    }

    func configure(with message: StoredMessage) {
        titleLabel.text = message.payload.title
        bodyLabel.text = message.payload.body
        sourceLabel.text = message.payload.channel.uppercased()
        unreadDot.isHidden = message.isRead

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        timeLabel.text = formatter.string(from: message.receivedAt)

        if message.payload.targetAppId != nil {
            iconImageView.image = UIImage(systemName: "app.badge.fill")
            iconContainer.backgroundColor = ThemeTokens.Color.info.withAlphaComponent(0.1)
            iconImageView.tintColor = ThemeTokens.Color.info
        } else if message.payload.targetURL != nil {
            iconImageView.image = UIImage(systemName: "link")
            iconContainer.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
            iconImageView.tintColor = ThemeColors.current.primary
        } else {
            iconImageView.image = UIImage(systemName: "bell.fill")
            iconContainer.backgroundColor = ThemeColors.current.warning.withAlphaComponent(0.1)
            iconImageView.tintColor = ThemeColors.current.warning
        }

        actionImageView.isHidden = (message.payload.targetURL == nil && message.payload.targetAppId == nil)
    }
}
