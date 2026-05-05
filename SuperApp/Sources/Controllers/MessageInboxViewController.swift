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

/// 消息收件箱视图控制器
class MessageInboxViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    private let messageManager = MessageManager.shared
    private let filterRelay = BehaviorRelay<FilterType>(value: .all)
    
    enum FilterType: Int {
        case all = 0
        case unread
        case apps
    }
    
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["全部", "未读", "应用"])
        control.selectedSegmentIndex = 0
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 100
        table.tableFooterView = UIView()
        table.backgroundColor = .systemGroupedBackground
        return table
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无消息"
        label.textColor = .secondaryLabel
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "消息中心"
        
        navigationItem.titleView = segmentedControl
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearAll))
        
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
        let filteredMessages = Observable.combineLatest(messageManager.messages, filterRelay)
            .map { messages, filter -> [WebhookMessage] in
                switch filter {
                case .all:
                    return messages
                case .unread:
                    return messages.filter { !$0.isRead }
                case .apps:
                    return messages.filter { $0.appId != nil }
                }
            }
            .share(replay: 1)

        filteredMessages
            .bind(to: tableView.rx.items(cellIdentifier: MessageCell.identifier, cellType: MessageCell.self)) { index, message, cell in
                cell.configure(with: message)
            }
            .disposed(by: disposeBag)
        
        filteredMessages
            .map { !$0.isEmpty }
            .bind(to: emptyLabel.rx.isHidden)
            .disposed(by: disposeBag)
        
        tableView.rx.modelSelected(WebhookMessage.self)
            .subscribe(onNext: { [weak self] message in
                self?.handleMessageClick(message)
            })
            .disposed(by: disposeBag)
    }
    
    private func handleMessageClick(_ message: WebhookMessage) {
        messageManager.markAsRead(id: message.id)
        
        if let urlString = message.url, let url = URL(string: urlString) {
            // 如果是 URL，直接打开
            let params = WebBrowserParams(payload: message.params)
            WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
        } else if let appId = message.appId {
            // 如果是 AppID，打开对应应用
            if let result = ManifestStore.shared.getManifestByAppId(appId),
               let url = URL(string: result.key) {
                print("🚀 [Inbox] Opening AppID: \(appId) with URL: \(url)")
                let params = WebBrowserParams(payload: message.params)
                WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
            } else {
                print("⚠️ [Inbox] AppID not found in cache: \(appId)")
                
                // 尝试从 AppID 本身解析 URL（有些推送可能直接把 URL 放在 appId 字段）
                if let url = URL(string: appId), (url.scheme == "http" || url.scheme == "https") {
                    let params = WebBrowserParams(payload: message.params)
                    WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
                } else {
                    // 弹出提示
                    let alert = UIAlertController(title: "无法打开应用", message: "未找到 AppID 为 \(appId) 的本地缓存。请确保该应用已安装或已同步。", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    @objc private func clearAll() {
        let alert = UIAlertController(title: "确认清空", message: "是否删除所有消息？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            self?.messageManager.clearAll()
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
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 12
        contentView.addSubview(cardView)
        
        iconContainer.layer.cornerRadius = 10
        iconContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = .tertiaryLabel
        
        sourceBadge.backgroundColor = UIColor.systemGray.withAlphaComponent(0.1)
        sourceBadge.layer.cornerRadius = 4
        sourceLabel.font = .systemFont(ofSize: 10, weight: .medium)
        sourceLabel.textColor = .secondaryLabel
        
        unreadDot.backgroundColor = .systemRed
        unreadDot.layer.cornerRadius = 4
        
        actionImageView.image = UIImage(systemName: "chevron.right")
        actionImageView.tintColor = .tertiaryLabel
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
    
    func configure(with message: WebhookMessage) {
        titleLabel.text = message.title
        bodyLabel.text = message.content
        sourceLabel.text = message.source.uppercased()
        unreadDot.isHidden = message.isRead
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)
        
        // 根据类型设置图标
        if message.appId != nil {
            iconImageView.image = UIImage(systemName: "app.badge.fill")
            iconContainer.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.1)
            iconImageView.tintColor = .systemIndigo
        } else if message.url != nil {
            iconImageView.image = UIImage(systemName: "link")
            iconContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            iconImageView.tintColor = .systemBlue
        } else {
            iconImageView.image = UIImage(systemName: "bell.fill")
            iconContainer.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
            iconImageView.tintColor = .systemOrange
        }
        
        // 如果不可点击，隐藏箭头
        actionImageView.isHidden = (message.url == nil && message.appId == nil)
    }
}
