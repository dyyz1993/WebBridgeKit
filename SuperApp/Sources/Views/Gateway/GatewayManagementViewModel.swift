import Foundation
import WebBridgeKit

@MainActor
final class GatewayManagementViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case validating
        case report
        case activated(String)
        case error(String)
    }

    @Published var payload = ""
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var report: HTMLAppGatewayValidationReport?
    @Published private(set) var gateways: [HTMLAppGatewayConfiguration] = []
    @Published private(set) var activeGatewayID: String?
    @Published var gatewayPendingRemoval: HTMLAppGatewayConfiguration?

    private let registry: HTMLAppGatewayRegistry
    private let onboardingService: HTMLAppGatewayOnboardingService
    private let allowsDevelopmentMode: Bool

    init(
        registry: HTMLAppGatewayRegistry,
        onboardingService: HTMLAppGatewayOnboardingService,
        allowsDevelopmentMode: Bool
    ) {
        self.registry = registry
        self.onboardingService = onboardingService
        self.allowsDevelopmentMode = allowsDevelopmentMode
        reload()
    }

    func reload() {
        gateways = registry.allGateways()
        activeGatewayID = registry.activeGateway()?.id
    }

    func usePayload(_ value: String) {
        payload = value
        validatePayload()
    }

    func validatePayload() {
        do {
            let gateway = try HTMLAppGatewayConfiguration.importPayload(
                payload,
                allowsDevelopmentHTTP: allowsDevelopmentMode
            )
            validate(gateway)
        } catch {
            report = nil
            phase = .error(error.localizedDescription)
        }
    }

    func validate(_ gateway: HTMLAppGatewayConfiguration) {
        phase = .validating
        report = nil
        onboardingService.validate(gateway) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let report):
                    self.report = report
                    self.phase = .report
                case .failure(let error):
                    self.phase = .error(error.localizedDescription)
                }
            }
        }
    }

    func activateReport() {
        guard let report else { return }
        do {
            try onboardingService.activate(report)
            reload()
            phase = .activated(report.displayName)
            self.report = nil
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func requestRemoval(_ gateway: HTMLAppGatewayConfiguration) {
        gatewayPendingRemoval = gateway
    }

    func confirmRemoval() {
        guard let gateway = gatewayPendingRemoval else { return }
        gatewayPendingRemoval = nil
        do {
            try onboardingService.removeGateway(id: gateway.id)
            reload()
            phase = .idle
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func clearFeedback() {
        if case .activated = phase { phase = .idle }
        if case .error = phase { phase = .idle }
    }
}
