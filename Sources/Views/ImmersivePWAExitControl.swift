//
//  ImmersivePWAExitControl.swift
//  WebBridgeKit
//

import UIKit

/// A movable host-owned exit affordance for immersive HTML applications.
public final class ImmersivePWAExitControl: UIControl {

    private enum Edge: Int {
        case left
        case right
    }

    private enum Presentation {
        case collapsed
        case expanded
    }

    public var onExit: (() -> Void)?
    /// Recovery is deliberately placed inside the expanded return capsule so
    /// immersive pages stay visually quiet until the user asks for controls.
    public var onRefresh: (() -> Void)?
    /// Expanded 收藏格：与两壳工具栏星标写入同一收藏表；点击只切换，不收起。
    public var onFavorite: (() -> Void)?
    /// 当前页面收藏态；由宿主在导航或切换后刷新，展开态实时反映。
    public var isFavorited: Bool = false {
        didSet {
            guard presentation == .expanded else { return }
            updateArrow()
        }
    }

    private let size: CGFloat = 44
    private let expandedWidth: CGFloat = 140
    private let collapsedVisibleWidth: CGFloat = 30
    /// Extends the tap target beyond the clipped visible sliver so a tap on
    /// the edge still registers instead of falling through to the PWA.
    private let hitAreaPadding: CGFloat = 20
    private let positionStore = UserDefaults.standard
    private let edgeKey = "com.webbridgekit.immersive-exit.edge"
    private let verticalRatioKey = "com.webbridgekit.immersive-exit.vertical-ratio"
    private let arrowImageView = UIImageView()
    private let refreshImageView = UIImageView()
    private let favoriteImageView = UIImageView()
    private let actionDivider = UIView()
    private let favoriteDivider = UIView()
    private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    private lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))

    private var edge: Edge = .left
    private var presentation: Presentation = .collapsed
    private var dragStartCenter: CGPoint = .zero
    private var isDragging = false

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitArea = bounds.insetBy(dx: -hitAreaPadding, dy: -hitAreaPadding)
        return hitArea.contains(point)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        restorePosition()
        setupAppearance()
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Repositions the control after safe-area or rotation changes.
    public func updateLayout(in hostView: UIView, animated: Bool = false) {
        let applyFrame = { [weak self, weak hostView] in
            guard let self, let hostView else { return }
            self.frame = self.frame(in: hostView)
            self.updateArrow()
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: applyFrame)
        } else {
            applyFrame()
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let superview else { return }

        switch presentation {
        case .collapsed:
            presentation = .expanded
            updateLayout(in: superview, animated: true)
        case .expanded:
            let location = gesture.location(in: self)
            if favoriteHitFrame.contains(location) {
                onFavorite?()
            } else if refreshHitFrame.contains(location) {
                onRefresh?()
                presentation = .collapsed
                updateLayout(in: superview, animated: true)
            } else {
                onExit?()
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview else { return }

        switch gesture.state {
        case .began:
            isDragging = false
            presentation = .expanded
            dragStartCenter = center
        case .changed:
            let translation = gesture.translation(in: superview)
            isDragging = isDragging || abs(translation.x) > 3 || abs(translation.y) > 3
            guard isDragging else { return }

            let bounds = draggableBounds(in: superview)
            center = CGPoint(
                x: min(max(dragStartCenter.x + translation.x, bounds.minX), bounds.maxX),
                y: min(max(dragStartCenter.y + translation.y, bounds.minY), bounds.maxY)
            )
        case .ended, .cancelled, .failed:
            guard isDragging else { return }
            edge = center.x < superview.bounds.midX ? .left : .right
            saveVerticalPosition(in: superview)
            presentation = .collapsed
            updateLayout(in: superview, animated: true)
            DispatchQueue.main.async { [weak self] in self?.isDragging = false }
        default:
            break
        }
    }

    private func setupAppearance() {
        backgroundColor = ThemeTokens.Color.surface
        layer.cornerRadius = size / 2
        layer.borderWidth = 1
        layer.borderColor = ThemeTokens.Color.border.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        accessibilityIdentifier = "browserManager.immersiveReturnButton"
        addSubview(arrowImageView)
        addSubview(refreshImageView)
        addSubview(favoriteImageView)
        actionDivider.backgroundColor = ThemeTokens.Color.border
        addSubview(actionDivider)
        favoriteDivider.backgroundColor = ThemeTokens.Color.border
        addSubview(favoriteDivider)
        updateArrow()
    }

    private func updateArrow() {
        let image: UIImage?
        let x: CGFloat

        switch presentation {
        case .expanded:
            image = LucideIcon.chevronLeft.templateImage(pointSize: 18, weight: .semibold)
            x = edge == .left ? 13 : expandedWidth - 31
            refreshImageView.image = LucideIcon.refresh.templateImage(pointSize: 18, weight: .semibold)
            refreshImageView.tintColor = ThemeTokens.Color.text
            refreshImageView.frame = refreshHitFrame.insetBy(dx: 13, dy: 13)
            refreshImageView.isHidden = false
            favoriteImageView.image = LucideIcon.star.templateImage(pointSize: 18, weight: .semibold)
            favoriteImageView.tintColor = isFavorited ? ThemeTokens.Color.warning : ThemeTokens.Color.text
            favoriteImageView.frame = favoriteHitFrame.insetBy(dx: 13, dy: 13)
            favoriteImageView.isHidden = false
            actionDivider.frame = CGRect(x: 43.5, y: 10, width: 1, height: size - 20)
            actionDivider.isHidden = false
            favoriteDivider.frame = CGRect(x: 91.5, y: 10, width: 1, height: size - 20)
            favoriteDivider.isHidden = false
            accessibilityLabel = isFavorited ? "返回、刷新或取消收藏" : "返回、刷新或收藏网页"
        case .collapsed:
            image = (edge == .left ? LucideIcon.chevronRight : LucideIcon.chevronLeft)
                .templateImage(pointSize: 18, weight: .semibold)
            x = edge == .left ? 12 : 1
            refreshImageView.isHidden = true
            favoriteImageView.isHidden = true
            actionDivider.isHidden = true
            favoriteDivider.isHidden = true
            accessibilityLabel = "显示退出 PWA"
        }

        arrowImageView.image = image
        arrowImageView.tintColor = ThemeTokens.Color.text
        arrowImageView.frame = CGRect(x: x, y: 13, width: 18, height: 18)
    }

    private func frame(in hostView: UIView) -> CGRect {
        let safeArea = hostView.safeAreaInsets
        let minY = safeArea.top + 10
        let maxY = max(minY, hostView.bounds.height - safeArea.bottom - size - 10)
        let ratio = min(max(positionStore.double(forKey: verticalRatioKey), 0), 1)
        let y = minY + (maxY - minY) * ratio

        let x: CGFloat
        let width: CGFloat
        switch presentation {
        case .expanded:
            width = expandedWidth
            x = edge == .left
                ? safeArea.left + 12
                : hostView.bounds.width - safeArea.right - expandedWidth - 12
        case .collapsed:
            width = size
            x = edge == .left
                ? safeArea.left - (size - collapsedVisibleWidth)
                : hostView.bounds.width - safeArea.right - collapsedVisibleWidth
        }

        return CGRect(x: x, y: y, width: width, height: size)
    }

    /// 展开态三格：左缘 [返回 0-44 | 刷新 48-92 | 收藏 96-140]，右缘镜像。
    private var refreshHitFrame: CGRect {
        CGRect(x: size + 4, y: 0, width: size, height: size)
    }

    private var favoriteHitFrame: CGRect {
        switch edge {
        case .left:
            return CGRect(x: 2 * size + 8, y: 0, width: size, height: size)
        case .right:
            return CGRect(x: 0, y: 0, width: size, height: size)
        }
    }

    private func draggableBounds(in hostView: UIView) -> CGRect {
        let safeArea = hostView.safeAreaInsets
        return CGRect(
            x: safeArea.left + size / 2,
            y: safeArea.top + size / 2 + 10,
            width: max(0, hostView.bounds.width - safeArea.left - safeArea.right - size),
            height: max(0, hostView.bounds.height - safeArea.top - safeArea.bottom - size - 20)
        )
    }

    private func restorePosition() {
        edge = Edge(rawValue: positionStore.integer(forKey: edgeKey)) ?? .left
        if positionStore.object(forKey: verticalRatioKey) == nil {
            positionStore.set(0.1, forKey: verticalRatioKey)
        }
    }

    private func saveVerticalPosition(in hostView: UIView) {
        let safeArea = hostView.safeAreaInsets
        let minY = safeArea.top + 10
        let maxY = max(minY, hostView.bounds.height - safeArea.bottom - size - 10)
        let ratio = maxY == minY ? 0 : (frame.minY - minY) / (maxY - minY)
        positionStore.set(edge.rawValue, forKey: edgeKey)
        positionStore.set(min(max(ratio, 0), 1), forKey: verticalRatioKey)
    }
}

extension ImmersivePWAExitControl: UIGestureRecognizerDelegate {
    /// The pan gesture must fail before the tap fires, so a quick tap
    /// expands the control instead of being eaten as a micro-drag.
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === panGesture, otherGestureRecognizer === tapGesture else { return false }
        return true
    }
}
