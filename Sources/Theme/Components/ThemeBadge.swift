import UIKit
import SnapKit

public enum ThemeBadgeStyle {
    case success
    case warning
    case error
    case info
    case `default`

    public var backgroundColor: UIColor {
        switch self {
        case .success: return ThemeColors.current.success.withAlphaComponent(0.12)
        case .warning: return ThemeColors.current.warning.withAlphaComponent(0.12)
        case .error: return ThemeColors.current.error.withAlphaComponent(0.12)
        case .info: return ThemeColors.current.info.withAlphaComponent(0.12)
        case .default: return ThemeColors.current.badgeBackground
        }
    }

    public var textColor: UIColor {
        switch self {
        case .success: return ThemeColors.current.success
        case .warning: return ThemeColors.current.warning
        case .error: return ThemeColors.current.error
        case .info: return ThemeColors.current.info
        case .default: return ThemeColors.current.badgeText
        }
    }
}

public class ThemeBadge: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        layer.cornerRadius = ThemeCornerRadius.default.sm
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }
    }

    public func configure(text: String, style: ThemeBadgeStyle = .default) {
        label.text = text
        label.textColor = style.textColor
        backgroundColor = style.backgroundColor
    }

    public func configure(text: String, color: UIColor) {
        label.text = text
        label.textColor = color
        backgroundColor = color.withAlphaComponent(0.12)
    }
}
