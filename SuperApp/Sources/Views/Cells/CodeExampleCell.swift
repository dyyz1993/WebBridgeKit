//
//  CodeExampleCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 代码示例单元格
class CodeExampleCell: UITableViewCell {

    static let identifier = "CodeExampleCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = UIColor.label
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let languageBadge: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        return view
    }()

    private let languageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.systemBlue
        label.textAlignment = .center
        return label
    }()

    private let codeTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = UIColor.label
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.layer.masksToBounds = true
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return textView
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: config), for: .normal)
        button.setTitle(" \(L10n.tr("common.copy"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        return view
    }()

    // MARK: - Properties

    private var currentExample: CodeExample?
    var onCopyTapped: (() -> Void)?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(languageBadge)
        containerView.addSubview(codeTextView)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(copyButton)
        languageBadge.addSubview(languageLabel)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(languageBadge.snp.left).offset(-8)
        }

        languageBadge.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(24)
        }

        languageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }

        codeTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.greaterThanOrEqualTo(80)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(codeTextView.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        copyButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-16)
        }

        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }

    // MARK: - Configuration

    func configure(with example: CodeExample) {
        currentExample = example

        titleLabel.text = example.title
        languageLabel.text = example.language
        codeTextView.text = example.code

        if example.description.isEmpty {
            descriptionLabel.isHidden = true
        } else {
            descriptionLabel.isHidden = false
            descriptionLabel.text = example.description
        }
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        onCopyTapped?()
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentExample = nil
        titleLabel.text = ""
        languageLabel.text = ""
        codeTextView.text = ""
        descriptionLabel.text = ""
        onCopyTapped = nil
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // 计算代码文本的高度
        let codeSize = codeTextView.sizeThatFits(CGSize(width: codeTextView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        codeTextView.snp.updateConstraints { make in
            make.height.equalTo(codeSize.height)
        }
    }
}
