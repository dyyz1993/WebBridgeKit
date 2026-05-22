import UIKit
import SnapKit

public final class WBKScreenScaffold: UIView {

    public enum Style {
        case standard
        case grouped
        case scrollable
    }

    private let style: Style
    private let _scrollView = UIScrollView()
    private let _contentStack = UIStackView()

    private var lastSectionSpacing: CGFloat = 0

    public var scrollView: UIScrollView? {
        switch style {
        case .standard: return nil
        case .grouped, .scrollable: return _scrollView
        }
    }

    public var contentStack: UIStackView { _contentStack }

    public init(style: Style = .standard) {
        self.style = style
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_screen_scaffold"
        setupUI()
    }

    required init?(coder: NSCoder) {
        self.style = .standard
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = resolveBackgroundColor()

        switch style {
        case .standard:
            addSubview(_contentStack)
            _contentStack.axis = .vertical
            _contentStack.alignment = .fill
            _contentStack.snp.makeConstraints { make in
                make.edges.equalTo(safeAreaLayoutGuide)
                    .inset(UIEdgeInsets(top: ThemeTokens.Spacing.screenTop,
                                        left: ThemeTokens.Spacing.screenHorizontal,
                                        bottom: ThemeTokens.Spacing.screenBottom,
                                        right: ThemeTokens.Spacing.screenHorizontal))
            }

        case .grouped, .scrollable:
            addSubview(_scrollView)
            _scrollView.alwaysBounceVertical = true
            _scrollView.snp.makeConstraints { make in
                make.edges.equalTo(safeAreaLayoutGuide)
            }

            _scrollView.addSubview(_contentStack)
            _contentStack.axis = .vertical
            _contentStack.alignment = .fill
            _contentStack.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.width.equalToSuperview()
            }

            let leading = _contentStack.leadingAnchor
            let trailing = _contentStack.trailingAnchor
            leading.constraint(equalTo: _scrollView.contentLayoutGuide.leadingAnchor).isActive = true
            trailing.constraint(equalTo: _scrollView.contentLayoutGuide.trailingAnchor).isActive = true
        }

        if style == .scrollable {
            _scrollView.backgroundColor = resolveBackgroundColor()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = resolveBackgroundColor()
    }

    public func clearSections() {
        let views = _contentStack.arrangedSubviews
        for view in views {
            _contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    public func addSection(_ view: UIView) {
        addSection(view, spacing: ThemeTokens.Spacing.lg)
    }

    public func addSection(_ view: UIView, spacing: CGFloat) {
        if _contentStack.arrangedSubviews.isEmpty {
            _contentStack.addArrangedSubview(view)
        } else {
            let spacer = UIView()
            spacer.snp.makeConstraints { make in
                make.height.equalTo(spacing)
            }
            _contentStack.addArrangedSubview(spacer)
            _contentStack.addArrangedSubview(view)
        }

        if style == .standard {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        } else {
            view.snp.makeConstraints { make in
                make.leading.equalTo(_contentStack).offset(ThemeTokens.Spacing.screenHorizontal)
                make.trailing.equalTo(_contentStack).offset(-ThemeTokens.Spacing.screenHorizontal)
            }
        }
    }

    private func resolveBackgroundColor() -> UIColor {
        switch style {
        case .standard:
            return ThemeTokens.Color.background
        case .grouped:
            return ThemeTokens.Color.background
        case .scrollable:
            return ThemeTokens.Color.background
        }
    }
}
