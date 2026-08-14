import SnapKit
import UIKit
import WebBridgeKit

final class MessageMediaCardView: UIView {
    private let imageView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let statusLabel = UILabel()
    private var loadTask: URLSessionDataTask?
    private var heightConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    func load(source: String) {
        accessibilityValue = "loading"
        statusLabel.text = L10n.tr("message.detail.media_loading")
        statusLabel.textColor = ThemeTokens.Color.textSecondary
        statusLabel.isHidden = false
        placeholderIcon.image = LucideIcon.image.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg)
        placeholderIcon.tintColor = ThemeTokens.Color.info

        guard let url = URL(string: source) else {
            showFailure()
            return
        }

        loadTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let image = data.flatMap(UIImage.init(data:))
            DispatchQueue.main.async {
                guard let self else { return }
                guard let image, statusCode.map({ (200...299).contains($0) }) != false else {
                    self.showFailure()
                    return
                }
                self.imageView.image = image
                self.heightConstraint?.update(offset: 168)
                self.placeholderIcon.isHidden = true
                self.statusLabel.isHidden = true
                self.accessibilityValue = "loaded"
            }
        }
        loadTask?.resume()
    }

    private func setupUI() {
        backgroundColor = ThemeTokens.Color.surface
        layer.cornerRadius = ThemeTokens.CornerRadius.md
        clipsToBounds = true
        accessibilityIdentifier = "message.detail.media"
        accessibilityLabel = L10n.tr("message.detail.media_attachment")

        imageView.backgroundColor = ThemeTokens.Color.backgroundSecondary
        imageView.contentMode = .scaleAspectFill
        imageView.accessibilityIdentifier = "message.detail.mediaImage"

        placeholderIcon.contentMode = .scaleAspectFit

        statusLabel.font = ThemeTokens.Typography.metadata
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        addSubview(imageView)
        addSubview(placeholderIcon)
        addSubview(statusLabel)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            heightConstraint = make.height.equalTo(168).constraint
        }
        placeholderIcon.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-12)
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.lg)
        }
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(placeholderIcon.snp.bottom).offset(ThemeTokens.Spacing.sm)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.lg)
        }
    }

    private func showFailure() {
        imageView.image = nil
        heightConstraint?.update(offset: 96)
        placeholderIcon.image = LucideIcon.warning.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg)
        placeholderIcon.tintColor = ThemeTokens.Color.error
        placeholderIcon.isHidden = false
        statusLabel.text = L10n.tr("message.detail.media_unavailable")
        statusLabel.textColor = ThemeTokens.Color.error
        statusLabel.isHidden = false
        accessibilityValue = "failed"
    }
}
