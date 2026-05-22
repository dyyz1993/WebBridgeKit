import UIKit
import SnapKit
import WebBridgeKit

final class ActionTileGrid: UIView {

    private let gridStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.md
        return sv
    }()

    private var onTap: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(gridStack)
        gridStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(actions: [(LucideIcon, String, WBKActionTile.Style)], onTap: @escaping (Int) -> Void) {
        self.onTap = onTap
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rowSize = 2
        for rowIndex in stride(from: 0, to: actions.count, by: rowSize) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = ThemeTokens.Spacing.md
            row.distribution = .fillEqually

            for colIndex in 0..<rowSize {
                let actionIndex = rowIndex + colIndex
                if actionIndex < actions.count {
                    let (icon, title, style) = actions[actionIndex]
                    let tile = WBKActionTile(icon: icon, title: title, style: style)
                    let finalIndex = actionIndex
                    tile.onTap = { [weak self] in
                        self?.onTap?(finalIndex)
                    }
                    tile.snp.makeConstraints { make in
                        make.height.equalTo(ThemeTokens.ComponentContract.ActionTile.height)
                    }
                    row.addArrangedSubview(tile)
                } else {
                    let spacer = UIView()
                    spacer.snp.makeConstraints { make in
                        make.height.equalTo(ThemeTokens.ComponentContract.ActionTile.height)
                    }
                    row.addArrangedSubview(spacer)
                }
            }
            gridStack.addArrangedSubview(row)
        }
    }
}

final class ResourceListSection: UIView {

    private var headerView: WBKSectionHeader?
    private let cardsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.sm
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(cardsStack)
        cardsStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(header: WBKSectionHeader, cards: [WBKResourceCard]) {
        headerView?.removeFromSuperview()
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        headerView = header
        cardsStack.addArrangedSubview(header)
        for card in cards {
            card.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(ThemeTokens.ComponentContract.ResourceCard.minHeight)
                make.height.lessThanOrEqualTo(ThemeTokens.ComponentContract.ResourceCard.maxHeight)
            }
            cardsStack.addArrangedSubview(card)
        }
    }
}
