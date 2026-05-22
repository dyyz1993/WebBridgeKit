import UIKit
import WebBridgeKit
import SnapKit

#if DEBUG

class ThemeShowcaseViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private var currentMode: ThemeMode = .system

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "主题"
        view.backgroundColor = ThemeTokens.Color.background
        setupUI()
        Task { @MainActor in
            currentMode = await ThemeManager.shared.getMode()
            updateModeSelection()
        }
    }

    private func setupUI() {
        stackView.axis = .vertical
        stackView.spacing = ThemeTokens.Spacing.md
        stackView.alignment = .fill

        setupModeSelector()
        setupComponentShowcase()
        setupColorPalette()
        setupTypography()
        setupIconsGrid()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(ThemeTokens.Spacing.md)
            make.left.right.equalToSuperview().inset(ThemeTokens.Spacing.md)
            make.bottom.equalToSuperview().offset(-ThemeTokens.Spacing.lg)
            make.width.equalTo(scrollView).offset(-ThemeTokens.Spacing.md * 2)
        }
    }

    private func setupModeSelector() {
        let header = makeHeader("Theme Mode")
        stackView.addArrangedSubview(header)

        let segmentedControl = UISegmentedControl(items: ThemeMode.allCases.map { $0.rawValue.capitalized })
        segmentedControl.selectedSegmentIndex = 2
        segmentedControl.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let mode = ThemeMode.allCases[segmentedControl.selectedSegmentIndex]
            self.applyMode(mode)
        }, for: .valueChanged)
        stackView.addArrangedSubview(segmentedControl)
    }

    private func applyMode(_ mode: ThemeMode) {
        currentMode = mode
        Task { @MainActor in
            await ThemeManager.shared.apply(mode)
            if let window = view.window {
                await ThemeManager.shared.applyToWindow(window)
            }
            updateModeSelection()
        }
    }

    private func updateModeSelection() {}

    private func setupComponentShowcase() {
        stackView.addArrangedSubview(makeDivider())

        let header = makeHeader("Components")
        stackView.addArrangedSubview(header)

        let card = ThemeCard()
        let cardContent = UILabel()
        cardContent.text = "ThemeCard with sample content\nSecond line of content"
        cardContent.numberOfLines = 0
        cardContent.font = ThemeTokens.Typography.body
        cardContent.textColor = ThemeTokens.Color.text
        card.addContent(cardContent)
        cardContent.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeTokens.Spacing.md)
        }
        card.snp.makeConstraints { make in
            make.height.equalTo(80)
        }
        stackView.addArrangedSubview(card)

        let badgesStack = UIStackView()
        badgesStack.axis = .horizontal
        badgesStack.spacing = ThemeTokens.Spacing.sm
        badgesStack.distribution = .fill

        let badgeStyles: [(String, ThemeBadgeStyle)] = [
            ("Success", .success),
            ("Warning", .warning),
            ("Error", .error),
            ("Info", .info),
            ("Default", .default)
        ]
        for (text, style) in badgeStyles {
            let badge = ThemeBadge()
            badge.configure(text: text, style: style)
            badgesStack.addArrangedSubview(badge)
        }
        stackView.addArrangedSubview(badgesStack)

        let primaryButton = ThemeButton()
        primaryButton.configure(title: "Primary Button", style: .primary)
        primaryButton.snp.makeConstraints { make in make.height.equalTo(44) }
        stackView.addArrangedSubview(primaryButton)

        let secondaryButton = ThemeButton()
        secondaryButton.configure(title: "Secondary Button", style: .secondary)
        secondaryButton.snp.makeConstraints { make in make.height.equalTo(44) }
        stackView.addArrangedSubview(secondaryButton)

        let ghostButton = ThemeButton()
        ghostButton.configure(title: "Ghost Button", style: .ghost)
        ghostButton.snp.makeConstraints { make in make.height.equalTo(44) }
        stackView.addArrangedSubview(ghostButton)

        let emptyState = ThemeEmptyState()
        emptyState.configure(icon: .inbox, title: "No Items", description: "This is a ThemeEmptyState component showcase")
        stackView.addArrangedSubview(emptyState)

        let sectionHeaderDemo = ThemeSectionHeader()
        sectionHeaderDemo.configure(title: "ThemeSectionHeader", actionTitle: "Action")
        stackView.addArrangedSubview(sectionHeaderDemo)

        let gradientView = ThemeGradientView()
        gradientView.snp.makeConstraints { make in
            make.height.equalTo(60)
        }
        stackView.addArrangedSubview(gradientView)
    }

    private func setupColorPalette() {
        stackView.addArrangedSubview(makeDivider())

        let header = makeHeader("Color Palette")
        stackView.addArrangedSubview(header)

        let colors: [(String, UIColor)] = [
            ("primary", ThemeTokens.Color.primary),
            ("secondary", ThemeTokens.Color.secondary),
            ("background", ThemeTokens.Color.background),
            ("surface", ThemeTokens.Color.surface),
            ("text", ThemeTokens.Color.text),
            ("textSecondary", ThemeTokens.Color.textSecondary),
            ("border", ThemeTokens.Color.border),
            ("success", ThemeTokens.Color.success),
            ("warning", ThemeTokens.Color.warning),
            ("error", ThemeTokens.Color.error),
            ("info", ThemeTokens.Color.info),
            ("cardBackground", ThemeTokens.Color.cardBackground),
            ("gradientStart", ThemeTokens.Color.gradientStart),
            ("gradientEnd", ThemeTokens.Color.gradientEnd),
            ("badgeBackground", ThemeTokens.Color.badgeBackground),
            ("badgeText", ThemeTokens.Color.badgeText),
            ("divider", ThemeTokens.Color.separator),
            ("fabBackground", ThemeTokens.Color.fabBackground),
            ("navBarBg", ThemeTokens.Color.navigationBarBackground),
            ("navBarTitle", ThemeTokens.Color.navigationBarTitle),
            ("tabBarBg", ThemeTokens.Color.tabBarBackground)
        ]

        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = ThemeTokens.Spacing.sm
        flowLayout.minimumLineSpacing = ThemeTokens.Spacing.sm
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = .clear
        collectionView.register(ColorCell.self, forCellWithReuseIdentifier: "ColorCell")
        self.colorEntries = colors

        let height = ceil(Double(colors.count) / 3.0) * 56.0
        collectionView.snp.makeConstraints { make in
            make.height.equalTo(height)
        }
        stackView.addArrangedSubview(collectionView)
    }

    private var colorEntries: [(String, UIColor)] = []

    private func setupTypography() {
        stackView.addArrangedSubview(makeDivider())

        let header = makeHeader("Typography")
        stackView.addArrangedSubview(header)

        let fonts: [(String, UIFont)] = [
            ("largeTitle (28pt bold)", ThemeTokens.Typography.largeTitle),
            ("title1 (22pt bold)", ThemeTokens.Typography.title1),
            ("title2 (20pt semibold)", ThemeTokens.Typography.title2),
            ("headline (17pt semibold)", ThemeTokens.Typography.headline),
            ("body (15pt regular)", ThemeTokens.Typography.body),
            ("caption1 (13pt regular)", ThemeTokens.Typography.caption1),
            ("caption2 (11pt regular)", ThemeTokens.Typography.caption2)
        ]

        for (name, font) in fonts {
            let label = UILabel()
            label.text = name
            label.font = font
            label.textColor = ThemeTokens.Color.text
            stackView.addArrangedSubview(label)
        }
    }

    private func setupIconsGrid() {
        stackView.addArrangedSubview(makeDivider())

        let header = makeHeader("Lucide Icons (\(LucideIcon.allCases.count))")
        stackView.addArrangedSubview(header)

        let icons = LucideIcon.allCases
        let cols = 6
        let rows = ceil(Double(icons.count) / Double(cols))
        let iconGrid = UIView()

        for (index, icon) in icons.enumerated() {
            let row = index / cols
            let col = index % cols
            let imgView = UIImageView()
            imgView.image = icon.templateImage(pointSize: 20, weight: .regular)
            imgView.tintColor = ThemeTokens.Color.text
            imgView.contentMode = .scaleAspectFit
            iconGrid.addSubview(imgView)
            imgView.snp.makeConstraints { make in
                make.width.height.equalTo(36)
                make.left.equalToSuperview().offset(CGFloat(col) * 52)
                make.top.equalToSuperview().offset(CGFloat(row) * 44)
            }
        }

        iconGrid.snp.makeConstraints { make in
            make.height.equalTo(CGFloat(rows) * 44)
        }
        stackView.addArrangedSubview(iconGrid)
    }

    private func makeHeader(_ title: String) -> ThemeSectionHeader {
        let header = ThemeSectionHeader()
        header.configure(title: title)
        return header
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.separator
        view.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
        return view
    }
}

extension ThemeShowcaseViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        colorEntries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
        let (name, color) = colorEntries[indexPath.item]
        cell.configure(name: name, color: color)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - ThemeTokens.Spacing.sm * 2) / 3.0
        return CGSize(width: width > 0 ? width : 100, height: 48)
    }
}

private class ColorCell: UICollectionViewCell {
    private let colorView = UIView()
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        colorView.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = ThemeTokens.Color.border.cgColor
        contentView.addSubview(colorView)
        contentView.addSubview(nameLabel)
        colorView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(24)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(colorView.snp.bottom).offset(2)
            make.left.right.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, color: UIColor) {
        colorView.backgroundColor = color
        nameLabel.text = name
    }
}
#endif
