//
//  MessageInboxViewController.swift
//  DemoApp
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
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.tableFooterView = UIView()
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
        view.backgroundColor = .systemBackground
        title = "消息中心"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearAll))
        
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func bindData() {
        messageManager.messages
            .bind(to: tableView.rx.items(cellIdentifier: MessageCell.identifier, cellType: MessageCell.self)) { index, message, cell in
                cell.configure(with: message)
            }
            .disposed(by: disposeBag)
        
        messageManager.messages
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
            // 这里需要从 ManifestStore 查找
            print("🚀 [Inbox] Opening AppID: \(appId)")
            // TODO: 调用 WebBrowserManager 打开 appId
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

/// 消息 Cell
class MessageCell: UITableViewCell {
    static let identifier = "MessageCell"
    
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()
    private let unreadDot = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .tertiaryLabel
        
        unreadDot.backgroundColor = .systemRed
        unreadDot.layer.cornerRadius = 4
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(bodyLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadDot)
        
        unreadDot.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(12)
            make.size.equalTo(8)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalTo(unreadDot.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-12)
        }
        
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalTo(titleLabel)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-10)
        }
    }
    
    func configure(with message: WebhookMessage) {
        titleLabel.text = message.title
        bodyLabel.text = message.body
        unreadDot.isHidden = message.isRead
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)
    }
}
