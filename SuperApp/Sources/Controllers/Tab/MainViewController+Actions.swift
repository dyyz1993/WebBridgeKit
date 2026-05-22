import UIKit
import WebBridgeKit

extension MainViewController {

    func showActionSheet(url: URL) {
        let history = viewModel.getHistory(url: url)
        let alert = UIAlertController(
            title: history?.title ?? url.host ?? url.absoluteString,
            message: """
                \(L10n.tr("home.action_sheet.domain")): \(url.host ?? L10n.tr("common.unknown"))
                \(L10n.tr("home.action_sheet.cache_size")): \(history?.formattedSize ?? "0 KB")
                \(L10n.tr("home.action_sheet.visit_count_format", "\(history?.visitCount ?? 0)"))
                """,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: L10n.tr("home.action_sheet.open"), style: .default, handler: { [weak self] _ in
            self?.openURL(url)
        }))
        let isPinned = viewModel.isPinned(url: url)
        alert.addAction(UIAlertAction(title: isPinned ? L10n.tr("home.action_sheet.unpin") : L10n.tr("home.action_sheet.pin"), style: .default, handler: { [weak self] _ in
            self?.viewModel.togglePin(url: url)
            self?.viewModel.refreshData()
        }))
        alert.addAction(UIAlertAction(title: L10n.tr("home.action_sheet.favorite"), style: .default, handler: { [weak self] _ in
            self?.viewModel.addToFavorites(url: url)
            self?.showAlert(title: L10n.tr("common.success"), message: L10n.tr("home.action_sheet.favorited_message"))
            self?.viewModel.refreshData()
        }))
        alert.addAction(UIAlertAction(title: L10n.tr("home.action_sheet.clear_cache"), style: .destructive, handler: { [weak self] _ in
            self?.viewModel.clearCache(url: url)
            self?.viewModel.refreshData()
        }))
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    @objc func clearCacheTapped() {
        let alert = UIAlertController(
            title: "确认清理缓存",
            message: "将清除所有本地缓存数据，此操作不可撤销",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: "清理", style: .destructive) { [weak self] _ in
            WebCacheManager.shared.clearAll()
            self?.viewModel.refreshData()
            HUDService.shared.showSuccess(withStatus: "缓存已清理")
        })
        present(alert, animated: true)
    }

    func handleQuickAction(index: Int) {
        switch index {
        case 0: openScanner()
        case 1: CommandHandler.shared.checkClipboardOnForeground()
        case 2:
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 1
            }
        case 3: break
        default: break
        }
    }
}
