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
        stack.spacing = ThemeTokens.Spacing.md
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.title2
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 0
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        return label
    }()

    private let metaCard: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        return view
    }()

    private let metaStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        return stack
    }()

    private let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
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
        title = L10n.tr("message.detail.title")
        view.backgroundColor = ThemeColors.current.background
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

        addMetaRow(label: L10n.tr("message.detail.received_time"), value: formatter.string(from: message.receivedAt))
        addMetaRow(label: L10n.tr("message.detail.source"), value: message.payload.channel)
        if let group = message.payload.group {
            addMetaRow(label: L10n.tr("message.detail.group"), value: group)
        }
        if message.isRead, let readAt = message.readAt {
            addMetaRow(label: L10n.tr("message.detail.read_time"), value: formatter.string(from: readAt))
        }

        addAction(title: L10n.tr("message.detail.copy_content"), icon: .copy) { [weak self] in
            guard let self = self else { return }
            UIPasteboard.general.string = self.message.payload.body
            HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.copied"))
        }

        if let urlString = message.payload.targetURL, let url = URL(string: urlString) {
            addAction(title: L10n.tr("message.detail.open_link"), icon: .link) { [weak self] in
                guard let self = self else { return }
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(payload: self.message.payload.userInfo),
                    from: self
                )
            }
        }

        if let appId = message.payload.targetAppId {
            addAction(title: L10n.tr("message.detail.open_app"), icon: .appBadge) { [weak self] in
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

        addAction(title: L10n.tr("common.delete"), icon: .trash, isDestructive: true) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: L10n.tr("message.detail.confirm_delete_title"), message: L10n.tr("message.detail.confirm_delete_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: L10n.tr("common.delete"), style: .destructive) { _ in
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
        labelLabel.font = ThemeTokens.Typography.footnote
        labelLabel.textColor = ThemeTokens.Color.textTertiary
        labelLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = ThemeTokens.Typography.footnote
        valueLabel.textColor = ThemeColors.current.textSecondary
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

    private func addAction(title: String, icon: LucideIcon, isDestructive: Bool = false, handler: @escaping () -> Void) {
        let button: UIButton
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = "  \(title)"
            config.image = icon.templateImage(pointSize: 16)
            config.imagePadding = 8
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            config.baseBackgroundColor = ThemeColors.current.cardBackground
            if isDestructive {
                config.baseForegroundColor = ThemeTokens.Color.error
            }
            button = UIButton(configuration: config)
        } else {
            button = UIButton(type: .system)
            button.setTitle("  \(title)", for: .normal)
            button.setImage(icon.templateImage(pointSize: 16), for: .normal)
            if isDestructive {
                button.tintColor = ThemeTokens.Color.error
            }
        }
        button.contentHorizontalAlignment = .leading
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.clipsToBounds = true
        button.backgroundColor = ThemeColors.current.cardBackground

        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)

        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 48)
        heightConstraint.priority = .required
        heightConstraint.isActive = true

        actionStackView.addArrangedSubview(button)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }
}
