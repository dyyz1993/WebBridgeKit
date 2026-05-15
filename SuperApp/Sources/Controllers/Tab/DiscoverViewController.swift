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

    var collectionView: UICollectionView!

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    var sections: [DiscoverSection] = []

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

    func loadData() {
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
                name: "Bridge 交互",
                url: "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html",
                cacheStatus: .cached,
                cacheSize: "1.8 MB",
                lastAccessed: nil,
                descriptionText: L10n.tr("discover.recommended.weather.desc")
            ),
            DiscoverItem(
                name: "Bridge 设备",
                url: "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-device.html",
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

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }
}
