import UIKit
import WebBridgeKit

extension MessageDetailViewController {

    func configureNativeApprovalActions() {
        guard message.payload.hasNativeApprovalActions,
              let actions = message.payload.approval?.actions else { return }
        actions.forEach { action in
            let icon: LucideIcon = action.resultState == .approved ? .success : .clipboard
            let style: ActionStyle
            switch action.style {
            case .primary: style = .primary
            case .destructive: style = .destructive
            case .default, nil: style = .standard
            @unknown default: style = .standard
            }
            addAction(
                title: action.title,
                icon: icon,
                placement: .contextual,
                style: style,
                accessibilityIdentifier: "message.detail.approval.\(action.id)"
            ) { [weak self] in
                self?.handleApprovalAction(action)
            }
        }
    }

    private func handleApprovalAction(_ action: MessageApprovalAction) {
        guard !isSubmittingApproval else { return }
        if action.requiresReason == true {
            let alert = UIAlertController(
                title: action.title,
                message: L10n.tr("message.detail.approval_reason_prompt"),
                preferredStyle: .alert
            )
            alert.addTextField { field in
                field.placeholder = L10n.tr("message.detail.approval_reason_placeholder")
                field.accessibilityIdentifier = "message.detail.approval.reason"
            }
            alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: action.title, style: .destructive) { [weak self, weak alert] _ in
                let reason = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !reason.isEmpty else {
                    HUDService.shared.showError(withStatus: L10n.tr("message.detail.approval_reason_required"))
                    return
                }
                self?.submitApproval(action: action, values: ["reason": reason])
            })
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(
            title: L10n.tr("message.detail.approval_confirm_title"),
            message: action.title,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: action.title, style: .default) { [weak self] _ in
            self?.submitApproval(action: action, values: [:])
        })
        present(alert, animated: true)
    }

    private func submitApproval(action: MessageApprovalAction, values: [String: String]) {
        guard let requestID = message.payload.requestID,
              let revision = message.payload.revision else {
            HUDService.shared.showError(withStatus: L10n.tr("message.detail.approval_invalid"))
            return
        }
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: "com.webbridgekit.bark.server")
            ?? ServerConfigManager.shared.getActiveBaseURL()
            ?? "https://wbk.shanbox.19930810.xyz:8443"
        let deviceKey = defaults.string(forKey: "com.webbridgekit.bark.key") ?? ""
        isSubmittingApproval = true
        contextualActionStackView.isUserInteractionEnabled = false
        contextualActionStackView.alpha = 0.55
        approvalStateValueLabel?.text = L10n.tr("message.action.submitting")

        ApprovalResponseClient(baseURL: baseURL, deviceKey: deviceKey).respond(
            requestID: requestID,
            actionID: action.id,
            expectedRevision: revision,
            values: values
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmittingApproval = false
                self.contextualActionStackView.isUserInteractionEnabled = true
                self.contextualActionStackView.alpha = 1
                switch result {
                case .success(let response):
                    self.approvalStateValueLabel?.text = self.approvalTitle(for: response.state)
                    self.contextualActionStackView.isHidden = true
                    if let state = MessageActionState(rawValue: response.state) {
                        let updatedPayload = self.message.payload.updatingActionState(
                            state,
                            revision: response.revision
                        )
                        Task {
                            try? await MessageEngine.shared.receive(updatedPayload)
                        }
                    }
                    HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.approval_submitted"))
                case .failure(let error):
                    self.approvalStateValueLabel?.text = self.approvalStatePresentation().title
                    HUDService.shared.showError(withStatus: error.localizedDescription)
                }
            }
        }
    }

    private func approvalTitle(for rawState: String) -> String {
        switch MessageActionState(rawValue: rawState) {
        case .approved: return L10n.tr("message.action.approved")
        case .rejected: return L10n.tr("message.action.rejected")
        case .cancelled: return L10n.tr("message.action.cancelled")
        case .expired: return L10n.tr("message.action.expired")
        case .pending: return L10n.tr("message.action.pending")
        case nil: return L10n.tr("message.action.unspecified")
        @unknown default: return L10n.tr("message.action.unspecified")
        }
    }
}
