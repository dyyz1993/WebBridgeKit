//
//  SubsystemStatCell.swift
//  SuperApp
//
//  Subsystem statistics row cell.
//

import UIKit
import SnapKit
import WebBridgeKit

class SubsystemStatCell: UITableViewCell {

    static let reuseIdentifier = "SubsystemStatCell"

    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.md
        v.clipsToBounds = true
        return v
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.body
        l.textColor = ThemeTokens.Color.text
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption1
        l.textColor = ThemeTokens.Color.textSecondary
        return l
    }()

    private let entriesLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        l.textColor = ThemeTokens.Color.text
        l.textAlignment = .right
        return l
    }()

    private let sizeLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        l.textColor = ThemeTokens.Color.textSecondary
        l.textAlignment = .right
        return l
    }()

    private let hitRateBadge: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    private let hitRateLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        return l
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        v.clipsToBounds = true
        return v
    }()

    private let rightStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = ThemeTokens.Spacing.sm
        sv.distribution = .fill
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        selectionStyle = .default
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        iconContainer.addSubview(iconImageView)
        contentView.addSubview(iconContainer)
        contentView.addSubview(nameLabel)
        contentView.addSubview(subtitleLabel)
        for v in [entriesLabel, sizeLabel, hitRateBadge, statusDot] { rightStack.addArrangedSubview(v) }
        contentView.addSubview(rightStack)

        hitRateBadge.addSubview(hitRateLabel)

        iconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(rightStack.snp.leading).offset(-8)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
        }

        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-32)
            make.centerY.equalToSuperview()
        }

        entriesLabel.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(40)
        }

        sizeLabel.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(50)
        }

        hitRateBadge.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(44)
            make.height.equalTo(20)
        }

        hitRateLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statusDot.snp.makeConstraints { make in
            make.width.height.equalTo(8)
        }
    }

    func configure(with model: CacheDashboardViewModel.SubsystemStatItemModel) {
        iconImageView.image = UIImage(lucideId: model.iconName)
        iconContainer.backgroundColor = model.hasData ? ThemeTokens.Color.primary : ThemeTokens.Color.textTertiary

        nameLabel.text = model.nameZh
        subtitleLabel.text = model.statusText
        entriesLabel.text = model.entries
        sizeLabel.text = model.size

        if let hr = model.hitRate {
            hitRateBadge.isHidden = false
            hitRateLabel.text = hr
            let rate = Double(hr.replacingOccurrences(of: "%", with: "")) ?? 0
            hitRateBadge.backgroundColor = rate >= 80 ? ThemeTokens.Color.success : (rate >= 50 ? ThemeTokens.Color.secondary : ThemeTokens.Color.error)
        } else {
            hitRateBadge.isHidden = true
        }

        switch model.statusColorName {
        case "success": statusDot.backgroundColor = ThemeTokens.Color.success
        case "error": statusDot.backgroundColor = ThemeTokens.Color.error
        default: statusDot.backgroundColor = ThemeTokens.Color.textTertiary
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        subtitleLabel.text = nil
        entriesLabel.text = nil
        sizeLabel.text = nil
        hitRateBadge.isHidden = true
    }
}
