//
//  MessageDetailViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

class MessageDetailViewController: UIViewController {

    private let message: StoredMessage

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let metaCard: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        return view
    }()

    private let metaStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    private let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    init(message: StoredMessage) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息详情"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        configure()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(scrollView).offset(-32)
        }

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(bodyLabel)
        contentStackView.addArrangedSubview(metaCard)
        contentStackView.addArrangedSubview(actionStackView)

        metaCard.addSubview(metaStackView)
        metaStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }

    private func configure() {
        titleLabel.text = message.payload.title
        bodyLabel.text = message.payload.body

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        addMetaRow(label: "接收时间", value: formatter.string(from: message.receivedAt))
        addMetaRow(label: "来源", value: message.payload.channel)
        if let group = message.payload.group {
            addMetaRow(label: "分组", value: group)
        }
        if message.isRead, let readAt = message.readAt {
            addMetaRow(label: "已读时间", value: formatter.string(from: readAt))
        }

        addAction(title: "复制内容", icon: "doc.on.doc") { [weak self] in
            guard let self = self else { return }
            UIPasteboard.general.string = self.message.payload.body
            HUDService.shared.showSuccess(withStatus: "已复制到剪贴板")
        }

        if let urlString = message.payload.targetURL, let url = URL(string: urlString) {
            addAction(title: "打开链接", icon: "link") { [weak self] in
                guard let self = self else { return }
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(payload: self.message.payload.userInfo),
                    from: self
                )
            }
        }

        if let appId = message.payload.targetAppId {
            addAction(title: "打开应用", icon: "app.badge") { [weak self] in
                guard let self = self else { return }
                if let result = ManifestStore.shared.getManifestByAppId(appId),
                   let url = URL(string: result.key) {
                    WebBrowserManager.shared.openBrowser(
                        url: url,
                        params: WebBrowserParams(payload: self.message.payload.userInfo),
                        from: self
                    )
                }
            }
        }

        addAction(title: "删除", icon: "trash", isDestructive: true) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "确认删除", message: "确定要删除这条消息吗？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                Task {
                    await MessageEngine.shared.deleteMessage(id: self.message.id)
                    self.navigationController?.popViewController(animated: true)
                }
            })
            self.present(alert, animated: true)
        }
    }

    private func addMetaRow(label: String, value: String) {
        let container = UIView()
        let labelLabel = UILabel()
        labelLabel.text = label
        labelLabel.font = .systemFont(ofSize: 13, weight: .medium)
        labelLabel.textColor = .tertiaryLabel
        labelLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 13)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 0

        container.addSubview(labelLabel)
        container.addSubview(valueLabel)

        labelLabel.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.width.equalTo(70)
        }

        valueLabel.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalTo(labelLabel.snp.trailing).offset(8)
        }

        metaStackView.addArrangedSubview(container)
    }

    private func addAction(title: String, icon: String, isDestructive: Bool = false, handler: @escaping () -> Void) {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.setTitle("  \(title)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.contentHorizontalAlignment = .leading
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.backgroundColor = .secondarySystemGroupedBackground
        button.layer.cornerRadius = 10

        if isDestructive {
            button.tintColor = .systemRed
            button.setTitleColor(.systemRed, for: .normal)
        }

        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)

        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 48)
        heightConstraint.priority = .required
        heightConstraint.isActive = true

        actionStackView.addArrangedSubview(button)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
