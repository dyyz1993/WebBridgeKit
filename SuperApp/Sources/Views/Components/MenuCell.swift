//
//  MenuCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import WebBridgeKit

/// 菜单列表项单元格
class MenuCell: UITableViewCell {

    static let identifier = "MenuCell"

    // MARK: - UI Components

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeColors.current.primary
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = LucideIcon.chevronRight.templateImage(pointSize: 12)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Colors.Light.textTertiary
        return imageView
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    // MARK: - Properties

    public var prepareForReuseBag = DisposeBag()

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        prepareForReuseBag = DisposeBag()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .default
        backgroundColor = ThemeColors.current.background

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(arrowImageView)

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.centerY.equalToSuperview()
        }

        valueLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(12)
            make.right.equalTo(arrowImageView.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }

        arrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    // MARK: - Configure

    func configure(icon: String? = nil, title: String, value: String? = nil, showArrow: Bool = true) {
        if let icon = icon {
            iconImageView.image = UIImage(systemName: icon)
            iconImageView.isHidden = false
            titleLabel.snp.remakeConstraints { make in
                make.left.equalTo(iconImageView.snp.right).offset(12)
                make.centerY.equalToSuperview()
            }
        } else {
            iconImageView.isHidden = true
            titleLabel.snp.remakeConstraints { make in
                make.left.equalToSuperview().offset(16)
                make.centerY.equalToSuperview()
            }
        }

        titleLabel.text = title

        if let value = value {
            valueLabel.text = value
            valueLabel.isHidden = false
            arrowImageView.isHidden = !showArrow
        } else {
            valueLabel.isHidden = true
            arrowImageView.isHidden = !showArrow
        }

        if !showArrow {
            arrowImageView.isHidden = true
            valueLabel.snp.remakeConstraints { make in
                make.right.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }
        }
    }
}
