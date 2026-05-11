//
//  PresetURLCell.swift
//  SuperApp
//
//  Preset URL catalog entry cell.
//

import UIKit
import SnapKit
import WebBridgeKit

class PresetURLCell: UITableViewCell {

    static let reuseIdentifier = "PresetURLCell"

    var onPinTapped: (() -> Void)?

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

    private let textStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.xs
        return sv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.body
        l.textColor = ThemeTokens.Color.text
        l.numberOfLines = 1
        return l
    }()

    private let descLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption1
        l.textColor = ThemeTokens.Color.textSecondary
        l.numberOfLines = 2
        return l
    }()

    private let metaStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 6
        sv.alignment = .center
        return sv
    }()

    private let urlLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        l.textColor = ThemeTokens.Color.textTertiary
        l.numberOfLines = 1
        return l
    }()

    private let typeBadge: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        v.clipsToBounds = true
        return v
    }()

    private let typeLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption2
        l.textColor = .white
        return l
    }()

    private let recommendedBadge: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    private let recommendedLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption2
        l.textColor = .white
        l.text = "推荐"
        return l
    }()

    private let pinButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(LucideIcon.pin.image(pointSize: 14), for: .normal)
        btn.tintColor = ThemeTokens.Color.primary
        btn.setTitle(" 置顶", for: .normal)
        btn.titleLabel?.font = ThemeTokens.Typography.caption2
        btn.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        btn.contentHorizontalAlignment = .right
        return btn
    }()

    private let pinnedCheckmark: UILabel = {
        let l = UILabel()
        l.text = "已置顶"
        l.font = ThemeTokens.Typography.caption2
        l.textColor = ThemeTokens.Color.success
        l.textAlignment = .right
        l.isHidden = true
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        selectionStyle = .default
        pinButton.addTarget(self, action: #selector(pinButtonTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        iconContainer.addSubview(iconImageView)
        typeBadge.addSubview(typeLabel)
        recommendedBadge.addSubview(recommendedLabel)
        for v in [typeBadge, recommendedBadge] { metaStack.addArrangedSubview(v) }
        for v in [titleLabel, descLabel, metaStack, urlLabel] { textStack.addArrangedSubview(v) }

        contentView.addSubview(iconContainer)
        contentView.addSubview(textStack)
        contentView.addSubview(pinButton)
        contentView.addSubview(pinnedCheckmark)

        iconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(36)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(pinButton.snp.leading).offset(-8)
            make.bottom.equalToSuperview().offset(-10)
        }

        pinButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
            make.height.equalTo(28)
        }

        pinnedCheckmark.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    @objc private func pinButtonTapped() {
        onPinTapped?()
    }

    func configure(with model: PresetURLCatalogViewModel.PresetURLItemModel) {
        iconImageView.image = UIImage(lucideId: "globe")
        iconContainer.backgroundColor = categoryColor(for: model.categoryDisplayName)

        titleLabel.text = model.title
        descLabel.text = model.description
        urlLabel.text = model.url

        typeLabel.text = model.urlTypeDisplayName
        typeBadge.backgroundColor = typeBadgeColor(for: model.urlTypeDisplayName)

        recommendedBadge.isHidden = !model.isRecommended

        if model.isAlreadyPinned {
            pinButton.isHidden = true
            pinnedCheckmark.isHidden = false
        } else {
            pinButton.isHidden = false
            pinnedCheckmark.isHidden = true
        }
    }

    private func categoryColor(for categoryName: String) -> UIColor {
        switch categoryName {
        case "HTML 页面": return ThemeTokens.Color.primary
        case "Web 应用": return ThemeTokens.Color.info
        case "API 接口": return ThemeTokens.Color.success
        case "静态资源": return ThemeTokens.Color.warning
        case "WebSocket": return ThemeTokens.Color.gradientEnd
        case "MCP 服务": return ThemeTokens.Color.error
        case "测试工具": return ThemeTokens.Color.info
        case "性能测试": return ThemeTokens.Color.info
        default: return ThemeTokens.Color.textTertiary
        }
    }

    private func typeBadgeColor(for typeName: String) -> UIColor {
        switch typeName {
        case "HTML 页面": return ThemeTokens.Color.primary.withAlphaComponent(0.8)
        case "Web 应用": return ThemeTokens.Color.info.withAlphaComponent(0.8)
        case "API 接口": return ThemeTokens.Color.success.withAlphaComponent(0.8)
        case "静态资源": return ThemeTokens.Color.warning.withAlphaComponent(0.8)
        case "WebSocket": return ThemeTokens.Color.gradientEnd.withAlphaComponent(0.8)
        case "MCP 服务": return ThemeTokens.Color.error.withAlphaComponent(0.8)
        case "Manifest": return ThemeTokens.Color.info.withAlphaComponent(0.8)
        default: return ThemeTokens.Color.textTertiary
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        descLabel.text = nil
        urlLabel.text = nil
        onPinTapped = nil
        recommendedBadge.isHidden = true
        pinButton.isHidden = false
        pinnedCheckmark.isHidden = true
    }
}
