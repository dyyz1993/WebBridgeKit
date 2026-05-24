import UIKit
import SnapKit

public class ThemeCard: UIView {
    private let contentView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: ThemeTokens.Shadows.card.offsetX, height: ThemeTokens.Shadows.card.offsetY)
        view.layer.shadowRadius = ThemeTokens.Shadows.card.radius
        view.layer.shadowOpacity = Float(ThemeTokens.Shadows.card.opacity)
        return view
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        contentView.backgroundColor = ThemeTokens.Color.cardBackground
    }

    public func addContent(_ view: UIView) {
        contentView.addSubview(view)
    }

    public var innerContentView: UIView {
        return contentView
    }
}
