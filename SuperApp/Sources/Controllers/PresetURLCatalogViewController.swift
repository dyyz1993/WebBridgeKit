//
//  PresetURLCatalogViewController.swift
//  SuperApp
//
//  Created on 2026-05-11.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import SnapKit
import WebBridgeKit

/// 预设 URL 目录 —— 浏览和导入预设 URL
class PresetURLCatalogViewController: BaseViewController<PresetURLCatalogViewModel> {

    // MARK: - UI
    private lazy var collectionView: UICollectionView = {
        let layout = Self.createLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = ThemeTokens.Color.background
        cv.register(PresetURLCell.self, forCellWithReuseIdentifier: PresetURLCell.reuseIdentifier)
        cv.register(UICollectionViewCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        cv.alwaysBounceVertical = true
        return cv
    }()

    private let searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "搜索预设 URL..."
        return sc
    }()

    private lazy var categorySegment: UISegmentedControl = {
        let items = ["全部"] + PresetCategory.allCases.sorted { $0.sortPriority < $1.sortPriority }.map(\.displayName)
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        return sc
    }()

    private let recommendedToggle: UISwitch = {
        let s = UISwitch()
        s.isOn = false
        return s
    }()

    private let recommendedLabel: UILabel = {
        let l = UILabel()
        l.text = "仅显示推荐"
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textColor = ThemeTokens.Color.textSecondary
        return l
    }()

    private let toggleStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = ThemeTokens.Spacing.sm
        sv.alignment = .center
        return sv
    }()

    // MARK: - Data
    private var items: [PresetURLCatalogViewModel.PresetURLItemModel] = []
    private let pinRelay = PublishRelay<PresetURLCatalogViewModel.PresetURLItemModel>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "预设 URL 目录"
        view.backgroundColor = ThemeTokens.Color.background

        setupUI()
        setupNavigation()
    }

    override func bindViewModel() {
        let category: PresetCategory?
        if categorySegment.selectedSegmentIndex > 0 {
            let sortedCats = PresetCategory.allCases.sorted { $0.sortPriority < $1.sortPriority }
            category = sortedCats[categorySegment.selectedSegmentIndex - 1]
        } else {
            category = nil
        }

        let input = PresetURLCatalogViewModel.Input(
            selectCategory: .just(category),
            searchQuery: searchController.searchBar.rx.text.orEmpty.debounce(.milliseconds(300), scheduler: MainScheduler.instance),
            pinTapped: pinRelay.asObservable(),
            showRecommendedOnly: recommendedToggle.rx.value.asObservable()
        )

        let output: PresetURLCatalogViewModel.Output = viewModel.transform(input: input)

        output.items
            .drive(onNext: { [weak self] (itemsList: [PresetURLCatalogViewModel.PresetURLItemModel]) in
                self?.items = itemsList
                self?.collectionView.reloadData()
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] (isEmpty: Bool) in
                if isEmpty {
                    self?.setEmptyState("无匹配结果", desc: "尝试其他关键词或分类")
                } else {
                    self?.clearEmptyState()
                }
            })
            .disposed(by: rx)

        output.pinResult
            .drive(onNext: { [weak self] (result: (item: PresetURLItem, success: Bool)) in
                if result.success {
                    let alert = UIAlertController(title: "已置顶", message: "\(result.item.title) 已添加到置顶列表", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self?.present(alert, animated: true)
                    self?.bindViewModel()
                } else {
                    let alert = UIAlertController(title: "失败", message: "无法添加到置顶列表", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self?.present(alert, animated: true)
                }
            })
            .disposed(by: rx)

        output.totalAvailable
            .drive(onNext: { _ in })
            .disposed(by: rx)
    }

    // MARK: - Setup
    private func setupUI() {
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }

        for v in [recommendedLabel, recommendedToggle] { toggleStack.addArrangedSubview(v) }

        navigationItem.titleView = categorySegment
        categorySegment.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)

        recommendedToggle.rx.value.changed.subscribe(onNext: { [weak self] _ in
            self?.bindViewModel()
        }).disposed(by: rx)

        collectionView.delegate = self
        collectionView.dataSource = self
    }

    private func setupNavigation() {
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    @objc private func categoryChanged() {
        bindViewModel()
    }

    // MARK: - Empty State Helper
    private func setEmptyState(_ title: String, desc: String) {
        let emptyView = UIView()
        emptyView.backgroundColor = .clear

        let iconLabel = UILabel()
        iconLabel.text = "📚"
        iconLabel.font = UIFont.systemFont(ofSize: 48)
        iconLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = ThemeTokens.Color.textSecondary
        titleLabel.textAlignment = .center

        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        descLabel.textColor = ThemeTokens.Color.textTertiary
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconLabel, titleLabel, descLabel])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.md
        stack.alignment = .center

        emptyView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }

        collectionView.backgroundView = emptyView
    }

    private func clearEmptyState() {
        collectionView.backgroundView = nil
    }

    // MARK: - Layout Factory
    private static func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(36))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]

            return section
        }
    }
}

// MARK: - UICollectionViewDataSource
extension PresetURLCatalogViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PresetURLCell.reuseIdentifier, for: indexPath)
        if let presetCell = cell as? PresetURLCell {
            presetCell.configure(with: items[indexPath.row])
            presetCell.onPinTapped = { [weak self] in
                self?.pinItem(at: indexPath)
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
            if header.subviews.filter({ $0 === self.toggleStack }).isEmpty {
                header.addSubview(toggleStack)
                toggleStack.snp.makeConstraints { make in
                    make.leading.equalTo(header).offset(16)
                    make.trailing.lessThanOrEqualTo(header).offset(-16)
                    make.centerY.equalTo(header)
                    make.top.bottom.equalTo(header).inset(4)
                }
            }
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate
extension PresetURLCatalogViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.row]

        let alert = UIAlertController(title: item.title, message: item.description, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "复制 URL", style: .default) { _ in
            UIPasteboard.general.string = item.url
        })
        alert.addAction(UIAlertAction(title: "在浏览器中打开", style: .default) { _ in
            if let url = URL(string: item.url) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "置顶此 URL", style: .default) { [weak self] _ in
            self?.pinItem(at: indexPath)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = collectionView
            popover.sourceRect = collectionView.cellForItem(at: indexPath)?.frame ?? .zero
        }

        present(alert, animated: true)
    }

    private func pinItem(at indexPath: IndexPath) {
        let item = items[indexPath.row]
        pinRelay.accept(item)
    }
}
