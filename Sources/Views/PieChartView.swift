//
//  PieChartView.swift
//  WebBridgeKit
//

import UIKit

public struct PieSegment {
    let value: CGFloat
    let color: UIColor
    let label: String

    public init(value: CGFloat, color: UIColor, label: String) {
        self.value = value
        self.color = color
        self.label = label
    }
}

public class PieChartView: UIView {

    public var segments: [PieSegment] = [] {
        didSet { setNeedsDisplay() }
    }

    public var centerText: String = "" {
        didSet { setNeedsDisplay() }
    }

    private let legendStack = UIStackView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLegend()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        setupLegend()
    }

    private func setupLegend() {
        legendStack.axis = .vertical
        legendStack.spacing = 6
        addSubview(legendStack)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let pieSize: CGFloat = 120
        legendStack.snp.remakeConstraints { make in
            make.left.equalTo(pieSize + 16)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(4)
            make.bottom.lessThanOrEqualToSuperview().offset(-4)
        }
    }

    public override func draw(_ rect: CGRect) {
        guard !segments.isEmpty else { return }

        let total = segments.reduce(0) { $0 + $1.value }
        guard total > 0 else { return }

        let pieSize: CGFloat = 120
        let center = CGPoint(x: pieSize / 2, y: pieSize / 2)
        let outerRadius = pieSize / 2 - 2
        let innerRadius: CGFloat = pieSize / 2 - 26

        var startAngle: CGFloat = -.pi / 2

        for segment in segments {
            let fraction = segment.value / total
            let endAngle = startAngle + fraction * 2 * .pi

            let path = UIBezierPath()
            path.move(to: pointOnCircle(center: center, radius: innerRadius, angle: startAngle))
            path.addArc(withCenter: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.addLine(to: pointOnCircle(center: center, radius: innerRadius, angle: endAngle))
            path.addArc(withCenter: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: false)
            path.close()

            segment.color.setFill()
            path.fill()

            startAngle = endAngle
        }

        if !centerText.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let size = centerText.size(withAttributes: attrs)
            let textRect = CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            centerText.draw(in: textRect, withAttributes: attrs)
        }

        updateLegend()
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func updateLegend() {
        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for seg in segments {
            let item = UIStackView()
            item.axis = .horizontal
            item.spacing = 6
            item.alignment = .center

            let dot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            dot.backgroundColor = seg.color
            dot.layer.cornerRadius = 3

            let label = UILabel()
            label.text = seg.label
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabel

            item.addArrangedSubview(dot)
            dot.snp.makeConstraints { make in
                make.width.height.equalTo(10)
            }
            item.addArrangedSubview(label)

            legendStack.addArrangedSubview(item)
        }
    }
}
