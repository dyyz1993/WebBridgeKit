//
//  DistributionChartView.swift
//  SuperApp
//
//  Storage distribution horizontal bar chart view.
//

import UIKit
import SnapKit
import WebBridgeKit

class DistributionChartView: UIView {

    private let titleHeader: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption2
        l.textColor = ThemeTokens.Color.textTertiary
        l.text = "存储分布"
        return l
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.sm
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let container = UIStackView(arrangedSubviews: [titleHeader, stackView])
        container.axis = .vertical
        container.spacing = ThemeTokens.Spacing.sm
        addSubview(container)
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(with distribution: [(name: String, size: Int64, percentage: Double)], totalSize: Int64) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !distribution.isEmpty else {
            let empty = UILabel()
            empty.text = "暂无数据"
            empty.font = ThemeTokens.Typography.caption1
            empty.textColor = ThemeTokens.Color.textTertiary
            empty.textAlignment = .center
            stackView.addArrangedSubview(empty)
            return
        }

        for item in distribution.prefix(8) {
            let barRow = DistributionBarRow()
            barRow.configure(name: item.name, percentage: item.percentage, size: item.size)
            stackView.addArrangedSubview(barRow)
        }
    }

    private class DistributionBarRow: UIView {

        private let nameLabel: UILabel = {
            let l = UILabel()
            l.font = ThemeTokens.Typography.caption2
            l.textColor = ThemeTokens.Color.textSecondary
            l.setContentHuggingPriority(.required, for: .horizontal)
            l.setContentCompressionResistancePriority(.required, for: .horizontal)
            return l
        }()

        private let trackView: UIView = {
            let v = UIView()
            v.backgroundColor = ThemeTokens.Color.border
            v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
            return v
        }()

        private let fillView: UIView = {
            let v = UIView()
            v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
            return v
        }()

        private let percentLabel: UILabel = {
            let l = UILabel()
            l.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            l.textColor = ThemeTokens.Color.textTertiary
            l.textAlignment = .right
            l.setContentHuggingPriority(.required, for: .horizontal)
            return l
        }()

        private let hStack: UIStackView = {
            let sv = UIStackView()
            sv.axis = .horizontal
            sv.spacing = ThemeTokens.Spacing.sm
            sv.alignment = .center
            return sv
        }()

        init() {
            super.init(frame: .zero)

            trackView.addSubview(fillView)
            for v in [nameLabel, trackView, percentLabel] { hStack.addArrangedSubview(v) }
            addSubview(hStack)

            hStack.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            fillView.snp.makeConstraints { make in
                make.leading.top.bottom.equalTo(trackView)
                make.width.equalTo(0)
            }

            nameLabel.snp.makeConstraints { make in
                make.width.greaterThanOrEqualTo(70)
            }

            trackView.snp.makeConstraints { make in
                make.height.equalTo(8)
            }

            percentLabel.snp.makeConstraints { make in
                make.width.greaterThanOrEqualTo(36)
            }
        }

        required init?(coder: NSCoder) { fatalError() }

        func configure(name: String, percentage: Double, size: Int64) {
            nameLabel.text = name
            percentLabel.text = String(format: "%.1f%%", percentage)

            let clampedPercent = min(max(percentage, 0), 100)
            fillView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalTo(trackView)
                make.width.equalTo(trackView).multipliedBy(clampedPercent / 100.0)
            }

            fillView.backgroundColor = barColor(for: name)
        }

        private func barColor(for name: String) -> UIColor {
            let colors: [UIColor] = [
                ThemeTokens.Color.primary,
                ThemeTokens.Color.secondary,
                ThemeTokens.Color.success,
                ThemeTokens.Color.warning,
                ThemeTokens.Color.gradientEnd,
                ThemeTokens.Color.info,
                ThemeTokens.Color.error,
                ThemeTokens.Color.info,
            ]
            let hash = abs(name.hashValue)
            return colors[hash % colors.count]
        }
    }
}
