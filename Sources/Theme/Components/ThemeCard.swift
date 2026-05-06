import UIKit
import SnapKit

public class ThemeCard: UIView {
    private let contentView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeCornerRadius.default.lg
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.08
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
        contentView.backgroundColor = ThemeColors.current.cardBackground
    }

    public func addContent(_ view: UIView) {
        contentView.addSubview(view)
    }

    public var innerContentView: UIView {
        return contentView
    }
}
