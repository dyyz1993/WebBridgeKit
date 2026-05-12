import UIKit
import SnapKit
import WebBridgeKit

// MARK: - Long Press

extension DiscoverViewController {
    func addLongPressGesture() {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(gesture)
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
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
