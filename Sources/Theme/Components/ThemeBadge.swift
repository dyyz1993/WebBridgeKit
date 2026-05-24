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
        case .success: return ThemeTokens.Color.success.withAlphaComponent(ThemeTokens.Opacity.badge)
        case .warning: return ThemeTokens.Color.warning.withAlphaComponent(ThemeTokens.Opacity.badge)
        case .error: return ThemeTokens.Color.error.withAlphaComponent(ThemeTokens.Opacity.badge)
        case .info: return ThemeTokens.Color.info.withAlphaComponent(ThemeTokens.Opacity.badge)
        case .default: return ThemeTokens.Color.primarySoft
        }
    }

    public var textColor: UIColor {
        switch self {
        case .success: return ThemeTokens.Color.success
        case .warning: return ThemeTokens.Color.warning
        case .error: return ThemeTokens.Color.error
        case .info: return ThemeTokens.Color.info
        case .default: return ThemeTokens.Color.textSecondary
        }
    }
}

public class ThemeBadge: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.badge
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
        layer.cornerRadius = ThemeTokens.CornerRadius.sm
        clipsToBounds = true
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: ThemeTokens.Spacing.xxs, left: ThemeTokens.Spacing.sm, bottom: ThemeTokens.Spacing.xxs, right: ThemeTokens.Spacing.sm))
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
        backgroundColor = color.withAlphaComponent(ThemeTokens.Opacity.badge)
    }
}
