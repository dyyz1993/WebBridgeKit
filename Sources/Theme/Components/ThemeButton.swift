import UIKit
import SnapKit

public enum ThemeButtonStyle {
    case primary
    case secondary
    case ghost

    public var backgroundColor: UIColor {
        switch self {
        case .primary: return ThemeColors.current.primary
        case .secondary: return ThemeColors.current.surface
        case .ghost: return .clear
        }
    }

    public var textColor: UIColor {
        switch self {
        case .primary: return .white
        case .secondary: return ThemeColors.current.text
        case .ghost: return ThemeColors.current.primary
        }
    }

    public var borderColor: UIColor? {
        switch self {
        case .primary: return nil
        case .secondary: return ThemeColors.current.border
        case .ghost: return ThemeColors.current.primary.withAlphaComponent(0.3)
        }
    }
}

public class ThemeButton: UIButton {
    public var style: ThemeButtonStyle = .primary {
        didSet { updateStyle() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        layer.cornerRadius = ThemeCornerRadius.default.md
        titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        updateStyle()
    }

    private func updateStyle() {
        backgroundColor = style.backgroundColor
        setTitleColor(style.textColor, for: .normal)
        if let borderColor = style.borderColor {
            layer.borderWidth = 1
            layer.borderColor = borderColor.cgColor
        } else {
            layer.borderWidth = 0
        }
    }

    public func configure(title: String, style: ThemeButtonStyle) {
        self.style = style
        setTitle(title, for: .normal)
    }

    public func configure(icon: LucideIcon, style: ThemeButtonStyle = .ghost, pointSize: CGFloat = 20) {
        self.style = style
        setImage(icon.templateImage(pointSize: pointSize), for: .normal)
    }
}
