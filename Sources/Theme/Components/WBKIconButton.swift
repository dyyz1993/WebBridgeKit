import UIKit
import SnapKit

public final class WBKIconButton: UIView {

    public enum Style {
        case `default`
        case bordered
        case filled
        case ghost
        case destructive
    }

    public enum Size {
        case small
        case medium
        case large

        var boxSize: CGFloat {
            switch self {
            case .small: return ThemeTokens.ComponentContract.TapTarget.minimumHeight
            case .medium: return ThemeTokens.ComponentContract.TapTarget.minimumWidth
            case .large: return 52
            }
        }

        var iconPointSize: CGFloat {
            switch self {
            case .small: return ThemeTokens.Icons.Sizes.sm
            case .medium: return ThemeTokens.Icons.Sizes.md
            case .large: return ThemeTokens.Icons.Sizes.lg
            }
        }
    }

    private let iconView = UIImageView()
    private let touchArea = UIButton(type: .system)
    private var currentIcon: LucideIcon
    private var currentStyle: Style
    private var currentSize: Size

    public var icon: LucideIcon {
        get { currentIcon }
        set {
            currentIcon = newValue
            updateIcon()
        }
    }

    public var style: Style {
        get { currentStyle }
        set {
            currentStyle = newValue
            updateAppearance()
        }
    }

    public var size: Size {
        get { currentSize }
        set {
            currentSize = newValue
            updateSize()
        }
    }

    public var isDisabled: Bool = false {
        didSet { updateDisabledState() }
    }

    public var onTap: (() -> Void)?

    public init(icon: LucideIcon, style: Style = .default, size: Size = .medium) {
        self.currentIcon = icon
        self.currentStyle = style
        self.currentSize = size
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }

    private func setupUI() {
        layer.cornerRadius = ThemeTokens.CornerRadius.md
        clipsToBounds = true
        isUserInteractionEnabled = true

        iconView.contentMode = .scaleAspectFit
        iconView.image = currentIcon.templateImage(pointSize: currentSize.iconPointSize)

        touchArea.addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        addSubview(iconView)
        addSubview(touchArea)

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(currentSize.iconPointSize)
        }

        touchArea.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        snp.makeConstraints { make in
            make.width.height.equalTo(max(currentSize.boxSize, 44))
        }

        updateAppearance()
    }

    @objc private func handleTap() {
        guard !isDisabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        onTap?()
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard !isDisabled else { return }
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = ThemeTokens.Opacity.pressed
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = self.isDisabled ? ThemeTokens.Opacity.disabled : 1.0
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = self.isDisabled ? ThemeTokens.Opacity.disabled : 1.0
        }
    }

    private func updateIcon() {
        iconView.image = currentIcon.templateImage(pointSize: currentSize.iconPointSize)
    }

    private func updateSize() {
        iconView.snp.updateConstraints { make in
            make.width.height.equalTo(currentSize.iconPointSize)
        }
        snp.updateConstraints { make in
            make.width.height.equalTo(max(currentSize.boxSize, 44))
        }
        updateIcon()
    }

    private func updateAppearance() {
        layer.borderWidth = 0
        layer.borderColor = nil

        switch currentStyle {
        case .default:
            backgroundColor = .clear
            iconView.tintColor = ThemeTokens.Color.primary
        case .bordered:
            backgroundColor = .clear
            layer.borderWidth = 1
            layer.borderColor = ThemeTokens.Color.border.cgColor
            iconView.tintColor = ThemeTokens.Color.primary
        case .filled:
            backgroundColor = ThemeTokens.Color.primary
            iconView.tintColor = ThemeTokens.Color.surface
        case .ghost:
            backgroundColor = .clear
            iconView.tintColor = ThemeTokens.Color.textSecondary
        case .destructive:
            backgroundColor = .clear
            iconView.tintColor = ThemeTokens.Color.error
        }
    }

    private func updateDisabledState() {
        isUserInteractionEnabled = !isDisabled
        alpha = isDisabled ? ThemeTokens.Opacity.disabled : 1.0
    }
}
