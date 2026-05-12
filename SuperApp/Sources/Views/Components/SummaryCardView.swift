//
//  SummaryCardView.swift
//  SuperApp
//
//  Dashboard summary card view.
//

import UIKit
import SnapKit
import WebBridgeKit

class SummaryCardView: UIView {

    private let containerView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        v.clipsToBounds = true
        return v
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.md
        sv.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        sv.isLayoutMarginsRelativeArrangement = true
        return sv
    }()

    private let headerStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = ThemeTokens.Spacing.sm
        return sv
    }()

    private lazy var totalSizeCard = createMetricCard(icon: .hardDrive, label: "总缓存")
    private lazy var totalEntriesCard = createMetricCard(icon: .docText, label: "总条目")
    private lazy var pinnedCountCard = createMetricCard(icon: .pin, label: "置顶数")
    private lazy var activeSystemsCard = createMetricCard(icon: .chartBar, label: "活跃系统")

    private let progressBar: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progressTintColor = ThemeTokens.Color.primary
        p.trackTintColor = ThemeTokens.Color.border
        p.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        p.clipsToBounds = true
        return p
    }()

    private let summaryLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption1
        l.textColor = ThemeTokens.Color.textSecondary
        l.textAlignment = .center
        l.numberOfLines = 1
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(stackView)

        for v in [totalSizeCard, totalEntriesCard, pinnedCountCard, activeSystemsCard] { headerStack.addArrangedSubview(v) }
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(progressBar)
        stackView.addArrangedSubview(summaryLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        applyTheme()
    }

    func configure(with data: DashboardData?) {
        guard let data else {
            totalSizeCard.valueLabel.text = "--"
            totalEntriesCard.valueLabel.text = "--"
            pinnedCountCard.valueLabel.text = "--"
            activeSystemsCard.valueLabel.text = "--"
            summaryLabel.text = "暂无数据"
            progressBar.setProgress(0, animated: false)
            return
        }

        totalSizeCard.valueLabel.text = data.formattedTotalSize
        totalEntriesCard.valueLabel.text = "\(data.totalEntries)"
        pinnedCountCard.valueLabel.text = "\(data.pinnedURLCount)"
        activeSystemsCard.valueLabel.text = "\(data.activeSubsystemCount)/\(data.subsystems.count)"

        let ratio = data.subsystems.isEmpty ? 0 : Double(data.activeSubsystemCount) / Double(data.subsystems.count)
        progressBar.setProgress(Float(ratio), animated: true)

        summaryLabel.text = "总计 \(data.formattedTotalSize) | \(data.totalEntries) 条目 | \(data.activeSubsystemCount)/\(data.subsystems.count) 子系统活跃"
    }

    private func applyTheme() {
        backgroundColor = .clear
        containerView.backgroundColor = ThemeTokens.Color.cardBackground
        let shadow = ThemeTokens.Shadows.Card
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = Float(shadow.opacity)
        containerView.layer.shadowRadius = shadow.radius
        containerView.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            applyTheme()
        }
    }

    private func createMetricCard(icon: LucideIcon, label: String) -> MetricCardView {
        MetricCardView(iconName: icon, labelText: label)
    }

    private class MetricCardView: UIView {

        let iconImageView: UIImageView = {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.tintColor = ThemeTokens.Color.primary
            return iv
        }()

        let valueLabel: UILabel = {
            let l = UILabel()
            l.font = ThemeTokens.Typography.title3
            l.textColor = ThemeTokens.Color.text
            l.textAlignment = .center
            return l
        }()

        let nameLabel: UILabel = {
            let l = UILabel()
            l.font = ThemeTokens.Typography.caption2
            l.textColor = ThemeTokens.Color.textTertiary
            l.textAlignment = .center
            return l
        }()

        init(iconName: LucideIcon, labelText: String) {
            super.init(frame: .zero)

            let stack = UIStackView(arrangedSubviews: [iconImageView, valueLabel, nameLabel])
            stack.axis = .vertical
            stack.spacing = ThemeTokens.Spacing.xs
            stack.alignment = .center

            addSubview(stack)
            stack.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(4)
            }

            iconImageView.image = iconName.image(pointSize: 16, weight: .medium)
            valueLabel.text = "0"
            nameLabel.text = labelText

            layer.cornerRadius = ThemeTokens.CornerRadius.md
            backgroundColor = ThemeTokens.Color.surface
        }

        required init?(coder: NSCoder) { fatalError() }
    }
}
