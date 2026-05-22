import UIKit
import SnapKit

public final class WBKStatusBadge: UIView {

    public enum Style: Equatable {
        case `default`
        case success
        case warning
        case error
        case info
        case offline
        case primary
        case custom(bgColor: UIColor, textColor: UIColor)

        var backgroundColor: UIColor {
            switch self {
            case .default: return ThemeTokens.Color.primarySoft
            case .success: return ThemeTokens.Color.successSoft
            case .warning: return ThemeTokens.Color.warningSoft
            case .error: return ThemeTokens.Color.errorSoft
            case .info: return ThemeTokens.Color.infoSoft
            case .offline: return ThemeTokens.Color.offlineSoft
            case .primary: return ThemeTokens.Color.primarySoft
            case .custom(let bgColor, _): return bgColor
            }
        }

        var textColor: UIColor {
            switch self {
            case .default: return ThemeTokens.Color.textSecondary
            case .success: return ThemeTokens.Color.success
            case .warning: return ThemeTokens.Color.warning
            case .error: return ThemeTokens.Color.error
            case .info: return ThemeTokens.Color.info
            case .offline: return ThemeTokens.Color.offline
            case .primary: return ThemeTokens.Color.primary
            case .custom(_, let textColor): return textColor
            }
        }
    }

    private let label = UILabel()

    public var text: String {
        get { label.text ?? "" }
        set {
            label.text = newValue
            invalidateIntrinsicContentSize()
        }
    }

    public var style: Style = .default {
        didSet { updateAppearance() }
    }

    public init(text: String, style: Style = .default) {
        self.style = style
        super.init(frame: .zero)
        setupUI(text: text)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }

    public override var intrinsicContentSize: CGSize {
        let textWidth = label.intrinsicContentSize.width
        return CGSize(width: textWidth + ThemeTokens.Spacing.sm * 2, height: 20)
    }

    private func setupUI(text: String) {
        layer.cornerRadius = ThemeTokens.CornerRadius.full
        clipsToBounds = true

        label.font = ThemeTokens.Typography.caption
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.text = text

        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.sm)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(ThemeTokens.Spacing.xs)
            make.bottom.greaterThanOrEqualToSuperview().offset(-ThemeTokens.Spacing.xs)
        }

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(20)
        }

        updateAppearance()
    }

    private func updateAppearance() {
        backgroundColor = style.backgroundColor
        label.textColor = style.textColor
        invalidateIntrinsicContentSize()
    }
}
