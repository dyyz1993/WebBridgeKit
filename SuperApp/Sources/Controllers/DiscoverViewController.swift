//
//  DiscoverViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

class DiscoverViewController: UIViewController {

    private let disposeBag = DisposeBag()

    private var collectionView: UICollectionView!

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private var sections: [DiscoverSection] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: LucideIcon.refresh.image(pointSize: 20),
            style: .plain,
            target: self,
            action: #selector(refreshData)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "刷新"

        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self = self else { return nil }
            return self.createSectionLayout(section: sectionIndex)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(DiscoverAppCell.self, forCellWithReuseIdentifier: DiscoverAppCell.identifier)
        collectionView.register(DiscoverSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: DiscoverSectionHeader.identifier)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        emptyStateView.configure(
            icon: "compass",
            title: L10n.tr("discover.empty.title"),
            description: L10n.tr("discover.empty.description"),
            actionTitle: nil
        )

        addLongPressGesture()
    }

    private func createSectionLayout(section: Int) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .estimated(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(150)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(40)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        sectionLayout.boundarySupplementaryItems = [header]

        return sectionLayout
    }

    @objc private func refreshData() {
        loadData()
    }

    private func loadData() {
        Task { @MainActor in
            await buildSections()
            collectionView.reloadData()
            collectionView.refreshControl?.endRefreshing()
            emptyStateView.isHidden = !sections.allSatisfy { $0.items.isEmpty }
        }
    }

    private func buildSections() async {
        var newSections: [DiscoverSection] = []

        let histories = (try? await WebPageHistoryManager.shared.getAllHistories()) ?? []
        let recentItems = histories.prefix(6).map { history -> DiscoverItem in
            let cacheStatus = DiscoverItem.CacheStatus(from: history)
            let cacheSize = ByteCountFormatter.string(fromByteCount: history.cachedSize, countStyle: .file)
            let lastAccessed = Self.relativeTimeString(for: history.lastVisitDate)
            return DiscoverItem(
                name: history.title ?? history.url,
                url: history.url,
                cacheStatus: cacheStatus,
                cacheSize: cacheSize,
                lastAccessed: lastAccessed
            )
        }
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.recent"), items: recentItems))

        var cachedItems: [DiscoverItem] = []
        let keys = ManifestStore.shared.getAllPageKeys()
        for key in keys {
            if let manifest = ManifestStore.shared.getManifest(for: key) {
                let name = manifest.name ?? key
                let cacheStatus: DiscoverItem.CacheStatus = manifest.persistent == true ? .persistent : .cached
                let entryURL = manifest.resources.values.first ?? key
                let cacheSize = ByteCountFormatter.string(
                    fromByteCount: PersistentManifestLoader.shared.getCacheSize(for: key),
                    countStyle: .file
                )
                let lastAccessed = manifest.lastUpdated.map { Self.relativeTimeString(for: $0) }
                cachedItems.append(DiscoverItem(
                    name: name,
                    url: entryURL,
                    cacheStatus: cacheStatus,
                    cacheSize: cacheSize,
                    lastAccessed: lastAccessed,
                    bundleID: "com.example.\(key.lowercased())",
                    version: "v1.0.0",
                    resourceCount: "\(manifest.resources.count) files",
                    cachedDate: manifest.lastUpdated.map { Self.dateFormatter.string(from: $0) },
                    expiresText: manifest.persistent == true ? L10n.tr("discover.detail.never") : L10n.tr("discover.detail.days_format", "7"),
                    visitCount: "-",
                    lastVisit: lastAccessed,
                    sourceText: L10n.tr("discover.detail.source_qr")
                ))
            }
        }
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.cached"), items: cachedItems))

        let recommendedItems: [DiscoverItem] = [
            DiscoverItem(
                name: "Weather",
                url: "https://weather.example.com",
                cacheStatus: .cached,
                cacheSize: "1.8 MB",
                lastAccessed: nil,
                descriptionText: L10n.tr("discover.recommended.weather.desc")
            ),
            DiscoverItem(
                name: "Notes",
                url: "https://notes.example.com",
                cacheStatus: .cached,
                cacheSize: "0.9 MB",
                lastAccessed: nil,
                descriptionText: L10n.tr("discover.recommended.notes.desc")
            )
        ]
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.recommended"), items: recommendedItems))

        sections = newSections
    }

    private static func relativeTimeString(for date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return L10n.tr("discover.time.just_now") }
        if interval < 3600 { return L10n.tr("discover.time.min_ago", "\(Int(interval / 60))") }
        if interval < 86400 { return L10n.tr("discover.time.hour_ago", "\(Int(interval / 3600))") }
        return L10n.tr("discover.time.days_ago", "\(Int(interval / 86400))")
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }
}

// MARK: - Models

struct DiscoverSection {
    let title: String
    let items: [DiscoverItem]
}

struct DiscoverItem {
    let name: String
    let url: String
    let cacheStatus: CacheStatus
    var cacheSize: String
    var lastAccessed: String?
    var descriptionText: String?
    var bundleID: String?
    var version: String?
    var resourceCount: String?
    var cachedDate: String?
    var expiresText: String?
    var visitCount: String?
    var lastVisit: String?
    var sourceText: String?
    var pushToken: String?

    enum CacheStatus {
        case persistent
        case cached
        case needsUpdate
        case notCached

        var displayText: String {
            switch self {
            case .persistent: return L10n.tr("discover.badge.saved")
            case .cached: return L10n.tr("discover.badge.saved")
            case .needsUpdate: return L10n.tr("discover.badge.temp")
            case .notCached: return L10n.tr("discover.badge.none")
            }
        }

        var statusTypeText: String {
            switch self {
            case .persistent: return L10n.tr("discover.status.persistent")
            case .cached: return L10n.tr("discover.status.persistent")
            case .needsUpdate: return L10n.tr("discover.status.temporary")
            case .notCached: return L10n.tr("discover.status.not_cached")
            }
        }

        var color: UIColor {
            switch self {
            case .persistent: return ThemeTokens.Color.success
            case .cached: return ThemeTokens.Color.success
            case .needsUpdate: return ThemeTokens.Color.warning
            case .notCached: return ThemeTokens.Color.textSecondary
            }
        }

        init(from history: WebPageHistory) {
            if history.isCached {
                self = .cached
            } else {
                self = .notCached
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension DiscoverViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DiscoverAppCell.identifier,
            for: indexPath
        ) as! DiscoverAppCell
        let item = sections[indexPath.section].items[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: DiscoverSectionHeader.identifier,
                for: indexPath
            ) as! DiscoverSectionHeader
            header.configure(title: sections[indexPath.section].title)
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate

extension DiscoverViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = sections[indexPath.section].items[indexPath.item]
        let detailVC = AppDetailViewController(item: item)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Long Press

extension DiscoverViewController {
    func addLongPressGesture() {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(gesture)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        let item = sections[indexPath.section].items[indexPath.item]
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showItemActionSheet(item: item)
    }

    private func showItemActionSheet(item: DiscoverItem) {
        let alert = UIAlertController(
            title: item.name,
            message: "\(L10n.tr("discover.action_sheet.cache")): \(item.cacheSize)\(item.lastAccessed.map { " · \(L10n.tr("discover.action_sheet.visit")): \($0)" } ?? "")",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.open"), style: .default) { [weak self] _ in
            self?.openURL(item.url)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.delete_cache"), style: .destructive) { [weak self] _ in
            self?.deleteCache(for: item)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.share"), style: .default) { [weak self] _ in
            self?.shareURL(item.url)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    private func deleteCache(for item: DiscoverItem) {
        if let url = URL(string: item.url) {
            PersistentManifestLoader.shared.clearCache(for: url)
        }
        ManifestStore.shared.removeManifest(for: item.name)
        loadData()
    }

    private func shareURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }
}

// MARK: - DiscoverSectionHeader

class DiscoverSectionHeader: UICollectionReusableView {

    static let identifier = "DiscoverSectionHeader"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}

// MARK: - DiscoverAppCell

class DiscoverAppCell: UICollectionViewCell {

    static let identifier = "DiscoverAppCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        let shadow = ThemeTokens.Shadows.Card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        return view
    }()

    private let topRowStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = ThemeTokens.Spacing.sm
        return sv
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.clipsToBounds = true
        return view
    }()

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.accessibilityLabel = "应用图标"
        return iv
    }()

    private let textStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.xs
        sv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return sv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        return label
    }()

    private let badgeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let bottomRowStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = ThemeTokens.Spacing.xs
        return sv
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 2
        return label
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        v.clipsToBounds = true
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = iconContainer.bounds
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)

        iconContainer.layer.addSublayer(gradientLayer)
        iconContainer.addSubview(iconImageView)
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(sizeLabel)
        badgeView.addSubview(badgeLabel)
        bottomRowStack.addArrangedSubview(statusDot)
        bottomRowStack.addArrangedSubview(detailLabel)

        topRowStack.addArrangedSubview(iconContainer)
        topRowStack.addArrangedSubview(textStack)
        topRowStack.addArrangedSubview(badgeView)

        let mainStack = UIStackView(arrangedSubviews: [topRowStack, bottomRowStack, descriptionLabel])
        mainStack.axis = .vertical
        mainStack.spacing = ThemeTokens.Spacing.sm
        cardView.addSubview(mainStack)

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        iconContainer.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }

        badgeView.snp.makeConstraints { make in
            make.height.equalTo(18)
        }

        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6))
        }

        statusDot.snp.makeConstraints { make in
            make.width.height.equalTo(6)
        }

        mainStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
        }
    }

    func configure(with item: DiscoverItem) {
        nameLabel.text = item.name
        sizeLabel.text = item.cacheSize
        badgeLabel.text = item.cacheStatus.displayText
        badgeLabel.textColor = item.cacheStatus.color
        badgeView.backgroundColor = item.cacheStatus.color.withAlphaComponent(ThemeTokens.Opacity.badge)

        let gradient = Self.gradientColors(for: item.name)
        gradientLayer.colors = [gradient.0.cgColor, gradient.1.cgColor]
        iconImageView.image = Self.icon(for: item.name).image(pointSize: 18)

        statusDot.backgroundColor = item.cacheStatus.color

        if let lastAccessed = item.lastAccessed {
            detailLabel.text = "\(item.cacheStatus.statusTypeText) · \(lastAccessed)"
        } else {
            detailLabel.text = item.cacheStatus.statusTypeText
        }

        if let desc = item.descriptionText, !desc.isEmpty {
            descriptionLabel.text = desc
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.isHidden = true
        }
    }

    private static let gradients: [(UIColor, UIColor)] = [
        (ThemeTokens.Color.gradientStart, ThemeTokens.Color.gradientEnd),
        (ThemeTokens.Color.primary, ThemeTokens.Color.gradientEnd),
        (ThemeTokens.Color.primary, ThemeTokens.Color.info),
        (ThemeTokens.Color.success, ThemeTokens.Color.primary),
        (ThemeTokens.Color.error, ThemeTokens.Color.warning),
        (ThemeTokens.Color.gradientEnd, ThemeTokens.Color.gradientStart),
    ]

    private static let icons: [LucideIcon] = [
        .globe,
        .appFill,
        .hardDrive,
        .doc,
        .star,
        .folder,
        .bell,
        .settings,
    ]

    private static func gradientColors(for name: String) -> (UIColor, UIColor) {
        gradients[abs(name.hashValue) % gradients.count]
    }

    private static func icon(for name: String) -> LucideIcon {
        icons[abs(name.hashValue) % icons.count]
    }
}
