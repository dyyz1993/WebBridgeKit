//
//  APIKeyManageViewController+TableView.swift
//  SuperApp
//
//  Extracted from APIKeyManageViewController.swift
//

import UIKit
import SnapKit
import WebBridgeKit

// MARK: - UITableViewDataSource

extension APIKeyManageViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTemporaryKeys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: APIKeyCell.identifier, for: indexPath) as? APIKeyCell else {
            return UITableViewCell()
        }

        let key = currentTemporaryKeys[indexPath.row]
        cell.configure(with: key, maskKey: false)
        cell.onCopyTap = { [weak self] keyValue in
            UIPasteboard.general.string = keyValue
            self?.showCopySuccess()
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension APIKeyManageViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let key = currentTemporaryKeys[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: L10n.tr("common.delete")) { [weak self] _, _, completion in
            self?.deleteKeySubject.onNext(key.id)
            completion(true)
        }
        deleteAction.image = LucideIcon.trash.image()

        let testAction = UIContextualAction(style: .normal, title: L10n.tr("apikey.manage.test")) { [weak self] _, _, completion in
            self?.viewModel.sendTemporaryKeyTestPush(key: key)
            completion(true)
        }
        testAction.backgroundColor = ThemeTokens.Color.success
        testAction.image = LucideIcon.send.image()

        let editAction = UIContextualAction(style: .normal, title: L10n.tr("common.edit")) { [weak self] _, _, completion in
            self?.showEditGroupIdDialog(for: key)
            completion(true)
        }
        editAction.backgroundColor = ThemeTokens.Color.primary
        editAction.image = LucideIcon.squarePencil.image()

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, testAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
