import UIKit

public final class WBKSkeletonView: UIView {

    public enum SkeletonShape {
        case rect(frame: CGRect, cornerRadius: CGFloat)
        case circle(center: CGPoint, radius: CGFloat)
        case roundedRect(frame: CGRect, cornerRadius: CGFloat)
    }

    private var shapeLayers: [UIView] = []
    private var shimmerGradient: CAGradientLayer?
    private var isShimmering = false

    private static let shimmerDuration: TimeInterval = 1.5

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        isAccessibilityElement = false
        isUserInteractionEnabled = false
        accessibilityLabel = "Loading"
        accessibilityTraits = .notEnabled
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(shapes: [SkeletonShape]) {
        shapeLayers.forEach { $0.removeFromSuperview() }
        shapeLayers.removeAll()
        shimmerGradient?.removeFromSuperlayer()
        shimmerGradient = nil

        for shape in shapes {
            let view = UIView()
            view.backgroundColor = ThemeTokens.Color.backgroundTertiary
            view.clipsToBounds = true

            switch shape {
            case .rect(let frame, let cornerRadius):
                view.frame = frame
                view.layer.cornerRadius = cornerRadius
            case .circle(let center, let radius):
                view.frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                view.layer.cornerRadius = radius
            case .roundedRect(let frame, let cornerRadius):
                view.frame = frame
                view.layer.cornerRadius = cornerRadius
            }

            addSubview(view)
            shapeLayers.append(view)
        }

        if !shapes.isEmpty {
            setupShimmerGradient()
        }
    }

    public func startShimmer() {
        guard !isShimmering else { return }
        isShimmering = true
        isHidden = false

        guard let gradient = shimmerGradient else { return }

        if UIAccessibility.isReduceMotionEnabled {
            for shape in shapeLayers {
                shape.alpha = 0.6
            }
            return
        }

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = Self.shimmerDuration
        animation.repeatCount = .infinity
        gradient.add(animation, forKey: "shimmer")
    }

    public func stopShimmer() {
        isShimmering = false
        isHidden = true
        shimmerGradient?.removeAllAnimations()

        for shape in shapeLayers {
            shape.alpha = 1.0
        }
    }

    private func setupShimmerGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            ThemeTokens.Color.backgroundSecondary.withAlphaComponent(0.6).cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [-1.0, -0.5, 0.0]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradient.frame = CGRect(
            x: -bounds.width,
            y: 0,
            width: bounds.width * 3,
            height: bounds.height
        )
        gradient.masksToBounds = true

        layer.addSublayer(gradient)
        shimmerGradient = gradient
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        shimmerGradient?.frame = CGRect(
            x: -bounds.width,
            y: 0,
            width: bounds.width * 3,
            height: bounds.height
        )
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            for shape in shapeLayers {
                shape.backgroundColor = ThemeTokens.Color.backgroundTertiary
            }
            if let gradient = shimmerGradient {
                gradient.colors = [
                    UIColor.clear.cgColor,
                    ThemeTokens.Color.backgroundSecondary.withAlphaComponent(0.6).cgColor,
                    UIColor.clear.cgColor
                ]
            }
        }
    }
}
