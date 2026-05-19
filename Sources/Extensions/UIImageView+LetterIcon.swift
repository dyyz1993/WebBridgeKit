import UIKit

public extension UIImageView {
    func setLetterIcon(for text: String?, size: CGSize = CGSize(width: 40, height: 40)) {
        let letter = (text ?? "?").prefix(1).uppercased()
        let renderer = UIGraphicsImageRenderer(size: size)

        let colors: [UIColor] = [
            ThemeTokens.Color.primary,
            ThemeTokens.Color.success,
            ThemeTokens.Color.warning,
            ThemeTokens.Color.secondary,
            ThemeTokens.Color.error,
            ThemeTokens.Color.info,
            ThemeTokens.Color.gradientStart
        ]
        let colorIndex = abs((text ?? "?").hashValue) % colors.count
        let bgColor = colors[colorIndex].withAlphaComponent(0.2)
        let textColor = colors[colorIndex]

        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            bgColor.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: size.width / 4).fill()

            let font = UIFont.systemFont(ofSize: size.width * 0.6, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]

            let stringSize = letter.size(withAttributes: attributes)
            let stringRect = CGRect(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )

            letter.draw(in: stringRect, withAttributes: attributes)
        }

        self.image = image
        self.backgroundColor = .clear
    }
}
