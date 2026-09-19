//
//  IconActionSheet.swift
//  WebBridgeKit
//
//  底部弹出的「图标 + 文字」格子面板（微信面板式）：格子按行铺开，超过一屏
//  横向滚动，项目多时折成两行；没有取消按钮，点遮罩关闭。图标可带状态色
//  （如收藏：未收藏描边星 / 已收藏警示色实心星），用于一眼读出当前状态。
//

import UIKit
import SnapKit

/// 单个面板项。`iconTint` 为 nil 时图标用正文色；需要状态色时显式传入
/// （如 ThemeTokens.Color.warning）。
public struct IconActionItem {
    public let icon: UIImage?
    public let title: String
    public let iconTint: UIColor?
    public let action: () -> Void

    public init(icon: UIImage?, title: String, iconTint: UIColor? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.iconTint = iconTint
        self.action = action
    }
}

public final class IconActionSheet: UIView {

    /// 每行可见格子数（微信面板同款密度）。
    private static let maxVisibleColumns = 4
    private static let tileSize = CGSize(width: 0, height: 76) // width 运行时按屏宽算
    private static let bottomSafeInset: CGFloat = 34

    // MARK: - UI Components

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.scrim
        return view
    }()

    private let panelView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.background
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceVertical = false
        return view
    }()

    private let columnsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .top
        stack.distribution = .fill
        return stack
    }()

    // MARK: - State

    private var items: [IconActionItem] = []
    private var isDismissed = false
    /// 当前展示中的面板（弱引用）。面板遮罩盖不住导航栏，⋯ 在面板开启时仍可
    /// 点击——重复触发必须收起而非叠加，保证面板有且仅有一个。
    private static weak var activeSheet: IconActionSheet?

    // MARK: - Initialization

    private override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Entry

    public static func show(in view: UIView, items: [IconActionItem]) {
        guard !items.isEmpty else { return }
        if let active = activeSheet, active.window != nil, !active.isDismissed {
            active.dismiss()
            return
        }
        let sheet = IconActionSheet(frame: .zero)
        sheet.items = items
        sheet.show(in: view)
        activeSheet = sheet
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(backgroundView)
        addSubview(panelView)

        panelView.addSubview(scrollView)
        scrollView.addSubview(columnsStack)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        panelView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.right.equalToSuperview()
            make.height.equalTo(Self.tileSize.height)
            make.bottom.equalToSuperview().offset(-Self.bottomSafeInset)
        }

        columnsStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        backgroundView.addGestureRecognizer(tapGesture)
    }

    /// 项目 ≤ 每行容量时一行铺开；超出时折成两行（列内竖排），再超宽横向滚动。
    private func rebuildColumns() {
        let rows = items.count > Self.maxVisibleColumns ? 2 : 1
        let tileWidth = UIScreen.main.bounds.width / CGFloat(Self.maxVisibleColumns)

        var columns: [[IconActionItem]] = []
        var current: [IconActionItem] = []
        for item in items {
            current.append(item)
            if current.count == rows {
                columns.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            columns.append(current)
        }

        columnsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for column in columns {
            let columnStack = UIStackView()
            columnStack.axis = .vertical
            for item in column {
                let tile = IconActionTile(item: item, size: CGSize(width: tileWidth, height: Self.tileSize.height))
                tile.onTap = { [weak self] in
                    self?.dismiss {
                        item.action()
                    }
                }
                columnStack.addArrangedSubview(tile)
            }
            columnsStack.addArrangedSubview(columnStack)
            columnStack.snp.makeConstraints { make in
                make.width.equalTo(tileWidth)
            }
        }
    }

    // MARK: - Show/Dismiss

    private func show(in view: UIView) {
        rebuildColumns()
        frame = view.bounds
        view.addSubview(self)
        layoutIfNeeded()

        backgroundView.alpha = 0
        panelView.transform = CGAffineTransform(translationX: 0, y: panelView.bounds.height)

        let animations = {
            self.backgroundView.alpha = 1
            self.panelView.transform = .identity
        }
        if UIAccessibility.isReduceMotionEnabled {
            animations()
        } else {
            UIView.animate(withDuration: ThemeTokens.Animation.slow.duration, delay: 0, options: .curveEaseOut, animations: animations)
        }
    }

    /// 先收起面板再执行动作，避免 HUD/跳转被遮罩盖住。
    private func dismiss(after completion: (() -> Void)? = nil) {
        guard !isDismissed else { return }
        isDismissed = true

        let finish = {
            self.removeFromSuperview()
            completion?()
        }
        if UIAccessibility.isReduceMotionEnabled {
            finish()
        } else {
            UIView.animate(
                withDuration: ThemeTokens.Animation.normal.duration,
                delay: 0,
                options: .curveEaseIn,
                animations: {
                    self.backgroundView.alpha = 0
                    self.panelView.transform = CGAffineTransform(translationX: 0, y: self.panelView.bounds.height)
                },
                completion: { _ in finish() }
            )
        }
    }

    @objc private func dismissTapped() {
        dismiss()
    }
}

// MARK: - 格子（图标在上、文字在下）

private final class IconActionTile: UIControl {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let item: IconActionItem
    var onTap: (() -> Void)?

    init(item: IconActionItem, size: CGSize) {
        self.item = item
        super.init(frame: .zero)
        setupUI()
        snp.makeConstraints { make in
            make.size.equalTo(size)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        iconView.contentMode = .scaleAspectFit
        if let icon = item.icon {
            iconView.image = item.iconTint.map { icon.withTintColor($0, renderingMode: .alwaysOriginal) } ?? icon
            iconView.tintColor = item.iconTint ?? ThemeTokens.Color.text
        }
        iconView.isHidden = item.icon == nil

        titleLabel.text = item.title
        titleLabel.font = ThemeTokens.Typography.footnote
        titleLabel.textColor = ThemeTokens.Color.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1

        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.size.equalTo(CGSize(width: 26, height: 26))
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(6)
            make.left.greaterThanOrEqualToSuperview().offset(4)
            make.right.lessThanOrEqualToSuperview().offset(-4)
            make.centerX.equalToSuperview()
        }

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = item.title
        accessibilityIdentifier = "actionsheet.\(item.title)"

        addTarget(self, action: #selector(tileTapped), for: .touchUpInside)
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.5 : 1.0
        }
    }

    @objc private func tileTapped() {
        onTap?()
    }
}
