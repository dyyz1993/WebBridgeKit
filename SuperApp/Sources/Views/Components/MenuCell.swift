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

class MenuCell: UITableViewCell {

    static let identifier = "MenuCell"

    private let iconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 7
        view.clipsToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        iv.tintColor = ThemeColors.current.textSecondary.withAlphaComponent(0.4)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    public var prepareForReuseBag = DisposeBag()

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

    private func setupUI() {
        selectionStyle = .default
        backgroundColor = ThemeColors.current.cardBackground

        contentView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(chevronImageView)

        iconContainer.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconContainer.snp.right).offset(12)
            make.centerY.equalToSuperview()
        }

        valueLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(12)
            make.right.equalTo(chevronImageView.snp.left).offset(-4)
            make.centerY.equalToSuperview()
        }

        chevronImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    func configure(icon: String? = nil, title: String, value: String? = nil, showArrow: Bool = true,
                   iconBackgroundColor: UIColor? = nil, iconTintColor: UIColor? = nil,
                   lucideIcon: LucideIcon? = nil) {

        if let bg = iconBackgroundColor {
            iconContainer.backgroundColor = bg
            iconContainer.isHidden = false
        } else if icon != nil || lucideIcon != nil {
            iconContainer.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
            iconContainer.isHidden = false
        } else {
            iconContainer.isHidden = true
        }

        if let tint = iconTintColor {
            iconImageView.tintColor = tint
        } else if iconBackgroundColor != nil {
            iconImageView.tintColor = ThemeColors.current.primary
        } else {
            iconImageView.tintColor = ThemeColors.current.primary
        }

        if let lucide = lucideIcon {
            iconImageView.image = lucide.image(pointSize: 18)
        } else if let iconName = icon {
            iconImageView.image = UIImage(systemName: iconName)
        } else {
            iconImageView.image = nil
        }

        titleLabel.text = title

        if let value = value {
            valueLabel.text = value
            valueLabel.isHidden = false
        } else {
            valueLabel.isHidden = true
        }

        chevronImageView.isHidden = !showArrow

        if !iconContainer.isHidden {
            titleLabel.snp.remakeConstraints { make in
                make.left.equalTo(iconContainer.snp.right).offset(12)
                make.centerY.equalToSuperview()
            }
        } else {
            titleLabel.snp.remakeConstraints { make in
                make.left.equalToSuperview().offset(16)
                make.centerY.equalToSuperview()
            }
        }

        if !showArrow {
            chevronImageView.isHidden = true
            valueLabel.snp.remakeConstraints { make in
                make.right.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }
        } else if !valueLabel.isHidden {
            valueLabel.snp.remakeConstraints { make in
                make.left.equalTo(titleLabel.snp.right).offset(12)
                make.right.equalTo(chevronImageView.snp.left).offset(-4)
                make.centerY.equalToSuperview()
            }
        }
    }
}
