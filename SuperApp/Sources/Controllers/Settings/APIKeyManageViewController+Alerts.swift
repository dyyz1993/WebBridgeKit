//
//  APIKeyManageViewController+Alerts.swift
//  SuperApp
//
//  Extracted from APIKeyManageViewController.swift
//

import UIKit
import SnapKit
import WebBridgeKit

// MARK: - Alert & Dialog Handlers

extension APIKeyManageViewController {

    func showKeyCreationDialog() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.create_title"),
            message: L10n.tr("apikey.manage.create_message"),
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = L10n.tr("apikey.manage.create_name_placeholder")
        }

        alert.addTextField { textField in
            textField.placeholder = L10n.tr("apikey.manage.create_group_placeholder")
        }

        let durations: [(String, TimeInterval)] = [
            (L10n.tr("apikey.manage.duration_1h"), 3600),
            (L10n.tr("apikey.manage.duration_1d"), 86400),
            (L10n.tr("apikey.manage.duration_7d"), 604800),
            (L10n.tr("apikey.manage.duration_30d"), 2592000)
        ]

        alert.addAction(UIAlertAction(title: L10n.tr("apikey.manage.next_step"), style: .default) { [weak self] _ in
            let name = alert.textFields?[0].text
            let groupId = alert.textFields?[1].text

            let durationAlert = UIAlertController(title: L10n.tr("apikey.manage.select_duration"), message: nil, preferredStyle: .actionSheet)
            for (title, duration) in durations {
                durationAlert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    self?.viewModel.addTemporaryKey(duration: duration, name: name, groupId: groupId)
                })
            }
            durationAlert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))

            if let popoverController = durationAlert.popoverPresentationController {
                popoverController.barButtonItem = self?.navigationItem.rightBarButtonItem
            }

            self?.present(durationAlert, animated: true)
        })

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        present(alert, animated: true)
    }

    func showRefreshSuccess() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.refresh_success"),
            message: L10n.tr("apikey.manage.refresh_success_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    func showCopySuccess() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.copy_success"),
            message: L10n.tr("apikey.manage.copy_success_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    func showAddSuccess() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.add_success"),
            message: L10n.tr("apikey.manage.add_success_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    func showTestPushResult(success: Bool, message: String) {
        let alert = UIAlertController(
            title: success ? L10n.tr("apikey.manage.test_success") : L10n.tr("apikey.manage.test_failure"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    func showExamples() {
        let examplesVC = APIKeyExampleViewController()
        navigationController?.pushViewController(examplesVC, animated: true)
    }

    func showEditGroupIdDialog(for key: APIKey) {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.edit_group_title"),
            message: L10n.tr("apikey.manage.edit_group_message", key.name),
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = L10n.tr("apikey.manage.group_id")
            textField.text = key.boundGroupId
        }

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("common.save"), style: .default) { [weak self] _ in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let newGroupId = alert.textFields?.first?.text
            self?.viewModel.updateKeyGroupId(id: key.id, groupId: newGroupId)
        })

        present(alert, animated: true)
    }
}
