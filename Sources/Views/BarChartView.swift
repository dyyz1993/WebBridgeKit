//
//  BarChartView.swift
//  WebBridgeKit
//

import UIKit

public struct BarItem {
    let value: CGFloat
    let color: UIColor
    let label: String

    public init(value: CGFloat, color: UIColor, label: String) {
        self.value = value
        self.color = color
        self.label = label
    }
}

public class BarChartView: UIView {

    public var items: [BarItem] = [] {
        didSet { setNeedsDisplay() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    public override func draw(_ rect: CGRect) {
        guard !items.isEmpty else { return }

        let maxValue = items.map(\.value).max() ?? 1
        guard maxValue > 0 else { return }

        let padding: CGFloat = 12
        let barAreaWidth = bounds.width - padding * 2
        let barCount = CGFloat(items.count)
        let barWidth: CGFloat = max(8, (barAreaWidth - (barCount - 1) * 6) / barCount)
        let spacing: CGFloat = 6
        let chartHeight = bounds.height - padding - 20

        for (index, item) in items.enumerated() {
            let x = padding + CGFloat(index) * (barWidth + spacing)
            let barHeight = max(4, (item.value / maxValue) * chartHeight)
            let y = bounds.height - 20 - barHeight

            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: 4)
            item.color.setFill()
            path.fill()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: ThemeTokens.Typography.caption2,
                .foregroundColor: ThemeTokens.Color.textTertiary
            ]
            let labelSize = item.label.size(withAttributes: attrs)
            let labelX = x + (barWidth - labelSize.width) / 2
            let labelY = bounds.height - 14
            item.label.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: attrs)
        }
    }
}
