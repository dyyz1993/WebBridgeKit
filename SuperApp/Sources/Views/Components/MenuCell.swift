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
        view.layer.cornerRadius = 8
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
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
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

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = ThemeTokens.Color.background
        label.textAlignment = .center
        label.backgroundColor = ThemeTokens.Color.success
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    let toggleSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isHidden = true
        return sw
    }()

    // Hero card views
    private let heroContainer: UIView = {
        let v = UIView()
        v.isHidden = true
        v.clipsToBounds = true
        return v
    }()

    private let heroIconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.clipsToBounds = true
        return v
    }()

    private let heroIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeTokens.Color.background
        return iv
    }()

    private let heroTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = ThemeColors.current.text
        return label
    }()

    private let heroSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        return label
    }()

    let copyTokenButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.layer.cornerRadius = 6
        btn.clipsToBounds = true
        btn.backgroundColor = ThemeTokens.Color.primary
        btn.setTitleColor(ThemeTokens.Color.background, for: .normal)
        btn.isHidden = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        return btn
    }()

    private(set) var hasToggle: Bool = false
    private(set) var isHero: Bool = false

    public var prepareForReuseBag = DisposeBag()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        prepareForReuseBag = DisposeBag()
        badgeLabel.isHidden = true
        toggleSwitch.isHidden = true
        hasToggle = false
        isHero = false
        heroContainer.isHidden = true
        copyTokenButton.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .default
        backgroundColor = ThemeColors.current.cardBackground

        contentView.addSubview(heroContainer)
        heroContainer.addSubview(heroIconContainer)
        heroIconContainer.addSubview(heroIconImageView)
        heroContainer.addSubview(heroTitleLabel)
        heroContainer.addSubview(heroSubtitleLabel)
        heroContainer.addSubview(copyTokenButton)

        contentView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(chevronImageView)
        contentView.addSubview(badgeLabel)
        contentView.addSubview(toggleSwitch)

        iconContainer.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
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

        badgeLabel.snp.makeConstraints { make in
            make.right.equalTo(chevronImageView.snp.left).offset(-6)
            make.centerY.equalToSuperview()
            make.height.equalTo(18)
        }

        toggleSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        heroContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(96)
        }

        heroIconContainer.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(56)
        }

        heroIconContainer.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(56)
        }

        heroIconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(28)
        }

        heroTitleLabel.snp.makeConstraints { make in
            make.left.equalTo(heroIconContainer.snp.right).offset(14)
            make.top.equalTo(heroIconContainer.snp.top).offset(4)
        }

        heroSubtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(heroTitleLabel)
            make.top.equalTo(heroTitleLabel.snp.bottom).offset(2)
        }

        copyTokenButton.snp.makeConstraints { make in
            make.left.equalTo(heroTitleLabel)
            make.top.equalTo(heroSubtitleLabel.snp.bottom).offset(8)
        }

        let gradient = CAGradientLayer()
        gradient.colors = [ThemeTokens.Color.gradientStart.cgColor, ThemeTokens.Color.gradientEnd.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        heroIconContainer.layer.insertSublayer(gradient, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradient = heroIconContainer.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = heroIconContainer.bounds
        }
    }

    func configure(icon: String? = nil, title: String, value: String? = nil, showArrow: Bool = true,
                   iconBackgroundColor: UIColor? = nil, iconTintColor: UIColor? = nil,
                   lucideIcon: LucideIcon? = nil, hasToggle: Bool = false, toggleIsOn: Bool = false,
                   badge: String? = nil, isHero: Bool = false) {
        self.hasToggle = hasToggle
        self.isHero = isHero

        if isHero {
            heroContainer.isHidden = false
            iconContainer.isHidden = true
            titleLabel.isHidden = true
            valueLabel.isHidden = true
            chevronImageView.isHidden = true
            badgeLabel.isHidden = true
            toggleSwitch.isHidden = true
            copyTokenButton.isHidden = false
            copyTokenButton.setTitle(L10n.tr("settings.hero.copy_token"), for: .normal)

            heroIconImageView.image = lucideIcon?.image(pointSize: 28)
            heroTitleLabel.text = "WebBridgeKit"
            heroSubtitleLabel.text = L10n.tr("settings.hero.token_masked")
            return
        }

        heroContainer.isHidden = true
        copyTokenButton.isHidden = true

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

        titleLabel.isHidden = false
        titleLabel.text = title

        if let value = value {
            valueLabel.isHidden = false
            valueLabel.text = value
        } else {
            valueLabel.isHidden = true
        }

        if hasToggle {
            toggleSwitch.isHidden = false
            toggleSwitch.isOn = toggleIsOn
            chevronImageView.isHidden = true
            selectionStyle = .none
        } else {
            toggleSwitch.isHidden = true
            chevronImageView.isHidden = !showArrow
            selectionStyle = .default
        }

        if let badgeText = badge {
            badgeLabel.isHidden = false
            badgeLabel.text = "  \(badgeText)  "
            badgeLabel.sizeToFit()
        } else {
            badgeLabel.isHidden = true
        }

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

        if hasToggle {
            toggleSwitch.snp.remakeConstraints { make in
                make.right.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }
            valueLabel.snp.remakeConstraints { make in
                make.right.equalTo(toggleSwitch.snp.left).offset(-8)
                make.centerY.equalToSuperview()
            }
        } else if !showArrow {
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

        if badge != nil {
            badgeLabel.snp.remakeConstraints { make in
                make.right.equalTo(hasToggle ? toggleSwitch.snp.left : chevronImageView.snp.left).offset(-6)
                make.centerY.equalToSuperview()
                make.height.equalTo(18)
            }
        }
    }
}
