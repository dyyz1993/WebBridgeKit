//
//  PinnedURLCell.swift
//  SuperApp
//
//  Pinned URL list cell.
//

import UIKit
import SnapKit
import WebBridgeKit

class PinnedURLCell: UITableViewCell {

    static let reuseIdentifier = "PinnedURLCell"

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

    private let mainStack: UIStackView = {
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

    private let detailStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    private let urlLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = ThemeTokens.Color.textSecondary
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

    private let accessLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption2
        l.textColor = ThemeTokens.Color.textTertiary
        return l
    }()

    private let pinIndicator: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(lucideId: "pin")
        iv.tintColor = ThemeTokens.Color.primary
        iv.isHidden = true
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        iconContainer.addSubview(iconImageView)
        typeBadge.addSubview(typeLabel)
        for v in [urlLabel, typeBadge, accessLabel] { detailStack.addArrangedSubview(v) }
        for v in [titleLabel, detailStack] { mainStack.addArrangedSubview(v) }

        contentView.addSubview(iconContainer)
        contentView.addSubview(mainStack)
        contentView.addSubview(pinIndicator)

        iconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(34)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18)
        }

        mainStack.snp.makeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(pinIndicator.snp.leading).offset(-4)
        }

        pinIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-32)
            make.centerY.equalToSuperview()
        }
    }

    func configure(with model: PinnedURLViewModel.PinnedURLItemModel) {
        iconImageView.image = UIImage(lucideId: model.iconName)
        iconContainer.backgroundColor = colorForType(model.urlType)

        titleLabel.text = model.title
        urlLabel.text = model.url

        typeLabel.text = model.typeName
        typeBadge.backgroundColor = colorForType(model.urlType)

        accessLabel.text = "访问 \(model.accessCount) 次 · \(model.formattedDate)"
        pinIndicator.isHidden = !model.isPinned
    }

    private func colorForType(_ type: URLType) -> UIColor {
        switch type {
        case .htmlPage: return ThemeTokens.Color.primary
        case .webApp: return ThemeTokens.Color.info
        case .apiEndpoint: return ThemeTokens.Color.success
        case .staticResource: return ThemeTokens.Color.warning
        case .websocket: return ThemeTokens.Color.gradientEnd
        case .mcpServer: return ThemeTokens.Color.error
        case .manifest: return ThemeTokens.Color.info
        case .other: return ThemeTokens.Color.textTertiary
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        urlLabel.text = nil
        typeLabel.text = nil
        accessLabel.text = nil
        pinIndicator.isHidden = true
    }
}
