//
//  MainViewController+Sections.swift
//  SuperApp
//
//  Compositional layout and collection view data source/delegate.
//

import UIKit
import SnapKit
import WebBridgeKit

extension MainViewController {

    func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }
            if sectionIndex == MainSection.pushToken.rawValue {
                return self.createPushTokenSection(environment: environment)
            } else if sectionIndex == MainSection.quickActions.rawValue {
                return self.createQuickActionsSection(environment: environment)
            } else {
                let gridSections = self.viewModel.historiesRelayValue.count
                return self.createAppGridSection(sectionIndex: sectionIndex, gridSections: gridSections, environment: environment)
            }
        }
    }

    private func createPushTokenSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        return section
    }

    private func createQuickActionsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.333), heightDimension: .absolute(110))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(110))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)
        group.interItemSpacing = .fixed(12)
        group.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
        return section
    }

    private func createAppGridSection(sectionIndex: Int, gridSections: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let containerWidth = environment.container.contentSize.width - 32
        let itemWidth = (containerWidth - 12) / 2
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(140))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(140))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140))
        let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitem: group, count: 2)
        row.interItemSpacing = .fixed(12)
        row.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let section = NSCollectionLayoutSection(group: row)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(36))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        return section
    }
}

extension MainViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2 + viewModel.historiesRelayValue.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == MainSection.pushToken.rawValue { return 1 }
        if section == MainSection.quickActions.rawValue { return 1 }
        let sections = viewModel.historiesRelayValue
        let gridIndex = section - MainSection.appGrid.rawValue
        guard gridIndex >= 0 && gridIndex < sections.count else { return 0 }
        return sections[gridIndex].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == MainSection.pushToken.rawValue {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: pushTokenCardCellId, for: indexPath) as! PushTokenCardCell
            cell.configure(serverURL: pushURL, deviceToken: deviceToken, isRegistered: isTokenRegistered)
            cell.onCopyTapped = { [weak self] in
                guard let self = self else { return }
                let token = PushNotificationManager.shared.deviceToken ?? ""
                let copyText = token.isEmpty ? self.pushURL : "\(self.pushURL)/\(token)"
                UIPasteboard.general.string = copyText
                self.showAlert(title: L10n.tr("home.token_card.copied_title"), message: L10n.tr("home.token_card.copied_message"))
            }
            cell.onRegisterTapped = { [weak self] in
                PushNotificationManager.shared.registerForPushNotifications()
                self?.showAlert(title: L10n.tr("home.token_card.registering_title"), message: L10n.tr("home.token_card.registering_message"))
            }
            return cell
        }
        if indexPath.section == MainSection.quickActions.rawValue {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: quickActionCellId, for: indexPath) as! QuickActionCell
            cell.configure(actions: quickActions)
            cell.onActionTapped = { [weak self] index in
                self?.handleQuickAction(index: index)
            }
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: URLGridCell.identifier, for: indexPath) as! URLGridCell
        let sections = viewModel.historiesRelayValue
        let gridIndex = indexPath.section - MainSection.appGrid.rawValue
        guard gridIndex >= 0 && gridIndex < sections.count else { return cell }
        let history = sections[gridIndex].items[indexPath.item]
        cell.history = history
        cell.onPinToggle = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            self.viewModel.togglePin(url: url)
            self.viewModel.refreshData()
        }
        cell.onFavoriteToggle = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            self.viewModel.toggleFavorite(url: url)
            self.viewModel.refreshData()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.identifier, for: indexPath) as! SectionHeaderView
            let sections = viewModel.historiesRelayValue
            let gridIndex = indexPath.section - MainSection.appGrid.rawValue
            if gridIndex >= 0 && gridIndex < sections.count {
                header.titleLabel.text = sections[gridIndex].header.uppercased()
            }
            return header
        }
        return UICollectionReusableView()
    }
}

extension MainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == MainSection.pushToken.rawValue { return }
        if indexPath.section == MainSection.quickActions.rawValue {
            handleQuickAction(index: indexPath.item)
            return
        }

        let sections = viewModel.historiesRelayValue
        let gridIndex = indexPath.section - MainSection.appGrid.rawValue
        guard gridIndex >= 0 && gridIndex < sections.count,
              indexPath.item < sections[gridIndex].items.count else { return }
        let history = sections[gridIndex].items[indexPath.item]
        guard !history.url.isEmpty, let url = URL(string: history.url) else { return }
        openURL(url)
    }
}
