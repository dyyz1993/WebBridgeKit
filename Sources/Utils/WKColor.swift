//
//  WKColor.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

// MARK: - DEPRECATED — Use ThemeTokens.Color.* instead
// This file is deprecated. All colors have been migrated to ThemeTokens.Color.
// Will be removed in a future version.

import UIKit

/// WebBridgeKit 颜色常量
public class WKColor: NSObject {

    public enum grey {
        public static let base = UIColor.systemGray
        public static let darken1 = UIColor.systemGray2
        public static let darken2 = UIColor.systemGray3
        public static let darken3 = UIColor.systemGray4
        public static let darken4 = UIColor.systemGray5
        public static let lighten1 = UIColor.systemGray5
        public static let lighten2 = UIColor.systemGray6
        public static let lighten3 = UIColor.systemGray6
        public static let lighten4 = UIColor.systemGray6
        public static let lighten5 = UIColor.systemGray6
    }

    public enum blue {
        public static let base = UIColor.systemBlue
        public static let darken1 = UIColor.systemBlue.withAlphaComponent(0.8)
        public static let darken5 = UIColor.systemBlue.withAlphaComponent(0.5)
    }

    public enum lightBlue {
        public static let darken3 = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
    }

    public static let white = UIColor.white
    public static let black = UIColor.black

    public enum background {
        public static let primary = UIColor.systemBackground
        public static let secondary = UIColor.secondarySystemBackground
    }
}

// MARK: - Letter Icon Extension

public extension UIImageView {
    /// 设置首字母图标
    /// - Parameters:
    ///   - text: 文本内容
    ///   - size: 图标大小
    func setLetterIcon(for text: String?, size: CGSize = CGSize(width: 40, height: 40)) {
        let letter = (text ?? "?").prefix(1).uppercased()
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { _ in
            // 背景色 (根据文字哈希生成颜色，保证同一个域名颜色一致)
            let colors: [UIColor] = [
                .systemBlue, .systemGreen, .systemOrange, .systemIndigo,
                .systemPurple, .systemTeal, .systemPink
            ]
            let colorIndex = abs((text ?? "?").hashValue) % colors.count
            let bgColor = colors[colorIndex].withAlphaComponent(0.2)
            let textColor = colors[colorIndex]

            let rect = CGRect(origin: .zero, size: size)
            bgColor.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: size.width / 4).fill()

            // 绘制文字
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
