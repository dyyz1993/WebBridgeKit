//
//  TextFieldCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 文本输入列表项单元格
class TextFieldCell: UITableViewCell {

    static let identifier = "TextFieldCell"

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeColors.current.text
        return label
    }()

    private let textField: UITextField = {
        let field = UITextField()
        field.font = ThemeTokens.Typography.subheadline
        field.textColor = ThemeColors.current.text
        field.clearButtonMode = .whileEditing
        field.borderStyle = .none
        return field
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeTokens.Color.error
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let separatorLine: UIView = {
        let line = UIView()
        line.backgroundColor = ThemeTokens.Color.separator
        return line
    }()

    // MARK: - Properties

    var onTextChange: ((String?) -> Void)?

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
        selectionStyle = .none
        backgroundColor = ThemeColors.current.background

        contentView.addSubview(titleLabel)
        contentView.addSubview(textField)
        contentView.addSubview(errorLabel)
        contentView.addSubview(separatorLine)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        textField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(32)
        }

        errorLabel.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        separatorLine.snp.makeConstraints { make in
            make.top.equalTo(errorLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(0.5)
            make.bottom.equalToSuperview().offset(-8)
        }

        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }

    // MARK: - Configure

    func configure(title: String, placeholder: String, text: String?, enabled: Bool = true, error: String? = nil) {
        titleLabel.text = title
        textField.placeholder = placeholder
        textField.text = text
        textField.isEnabled = enabled

        // Update appearance based on enabled state
        titleLabel.textColor = enabled ? ThemeColors.current.text : ThemeColors.current.textSecondary
        textField.textColor = enabled ? ThemeColors.current.text : ThemeColors.current.textSecondary

        // Update error state
        if let error = error, !error.isEmpty {
            errorLabel.text = error
            errorLabel.isHidden = false
            separatorLine.backgroundColor = ThemeTokens.Color.error
        } else {
            errorLabel.text = nil
            errorLabel.isHidden = true
            separatorLine.backgroundColor = ThemeTokens.Color.separator
        }
    }

    // MARK: - Actions

    @objc private func textFieldChanged() {
        onTextChange?(textField.text)
    }

    // MARK: - Public Methods

    func getText() -> String? {
        return textField.text
    }

    func setText(_ text: String?) {
        textField.text = text
    }

    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        textField.text = ""
        textField.placeholder = ""
        errorLabel.text = ""
        errorLabel.isHidden = true
        separatorLine.backgroundColor = ThemeTokens.Color.separator
        onTextChange = nil
    }
}
