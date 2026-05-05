//
//  SwitchCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

/// 开关列表项单元格
class SwitchCell: UITableViewCell {

    static let identifier = "SwitchCell"

    var prepareForReuseBag = DisposeBag()

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.label
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    let switchControl: UISwitch = {
        let switchControl = UISwitch()
        switchControl.onTintColor = UIColor.systemBlue
        return switchControl
    }()

    // MARK: - Properties

    var onSwitchChange: ((Bool) -> Void)?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        prepareForReuseBag = DisposeBag()
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = UIColor.systemBackground

        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(switchControl)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(switchControl.snp.left).offset(-12)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(switchControl.snp.left).offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }

        switchControl.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }

    // MARK: - Configure

    func configure(title: String, description: String? = nil, isOn: Bool) {
        titleLabel.text = title

        if let description = description {
            descriptionLabel.text = description
            descriptionLabel.isHidden = false
            titleLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.left.equalToSuperview().offset(16)
                make.right.equalTo(switchControl.snp.left).offset(-12)
            }
        } else {
            descriptionLabel.isHidden = true
            titleLabel.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(16)
                make.right.equalTo(switchControl.snp.left).offset(-12)
            }
        }

        switchControl.isOn = isOn
    }

    // MARK: - Actions

    @objc private func switchValueChanged() {
        onSwitchChange?(switchControl.isOn)
    }
}
