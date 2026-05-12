//
//  WebPageHistoryViewController+TableView.swift
//  WebBridgeKit
//
//  Extracted from WebPageHistoryViewController.swift
//

import RxDataSources
import RxSwift
import SnapKit
import UIKit

// MARK: - UITableViewDelegate

extension WebPageHistoryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        guard let history = try? dataSource.model(at: indexPath) as? WebPageHistory else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "Delete")) { [weak self] _, _, completion in
            Task { @MainActor in
                await self?.deleteHistory(history)
                completion(true)
            }
        }
        deleteAction.backgroundColor = ThemeTokens.Color.error

        let cacheAction: UIContextualAction
        if history.isCached {
            cacheAction = UIContextualAction(style: .normal, title: NSLocalizedString("Delete Cache", comment: "Delete Cache")) { _, _, completion in
                WebPageOfflineCacheManager.shared.deleteCache(history: history)
                HUDService.shared.showInfo(withStatus: NSLocalizedString("Cache deleted", comment: ""))
                completion(true)
            }
            cacheAction.backgroundColor = ThemeTokens.Color.warning
        } else {
            cacheAction = UIContextualAction(style: .normal, title: NSLocalizedString("Cache", comment: "Cache")) { [weak self] _, _, completion in
                self?.cachePage(history)
                completion(true)
            }
            cacheAction.backgroundColor = ThemeTokens.Color.info
        }

        return UISwipeActionsConfiguration(actions: [deleteAction, cacheAction])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataSource[section].model
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension WebPageHistoryViewController: UICollectionViewDelegateFlowLayout {
    // 已在初始化时配置
}

// MARK: - UICollectionViewDataSource

extension WebPageHistoryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allHistories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: WebPageHistoryGalleryCell.reuseIdentifier,
            for: indexPath
        ) as? WebPageHistoryGalleryCell,
        indexPath.item < allHistories.count else {
            return UICollectionViewCell()
        }

        cell.history = allHistories[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < allHistories.count else { return }
        let history = allHistories[indexPath.item]
        openHistory(history)
    }
}

// MARK: - QRScannerViewController

extension WebPageHistoryViewController {
    func handleQRScanResult(_ result: String) {
        if let url = URL(string: result) {
            Task { @MainActor in
                do {
                    try await WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: nil)
                } catch {
                    WebBridgeLogger.shared.log(.error, "Failed to add history from QR: \(error.localizedDescription)")
                }
            }

            self.openURL(url)
        } else if let url = URL(string: "https://" + result) {
            Task { @MainActor in
                do {
                    try await WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: nil)
                } catch {
                    WebBridgeLogger.shared.log(.error, "Failed to add history from QR: \(error.localizedDescription)")
                }
            }
            self.openURL(url)
        } else {
            HUDService.shared.showError(withStatus: NSLocalizedString("Invalid URL", comment: "Invalid URL"))
        }
    }
}

// MARK: - Localized Strings

private extension String {
    static func localized(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
}
