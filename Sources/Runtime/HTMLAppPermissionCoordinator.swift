//
//  HTMLAppPermissionCoordinator.swift
//  WebBridgeKit
//
//  Serializes branded permission prompts: one panel at a time, duplicate
//  requests merge, and every bridge completion fires exactly once.
//

import Foundation

/// Everything the branded consent panel needs to explain a request.
public struct HTMLAppPermissionPromptContext: Equatable, Sendable {
    public let appName: String
    public let origin: String
    public let capability: HTMLAppCapability
    public let reason: String
    public let requestedScope: HTMLAppPermissionScope

    public init(
        appName: String,
        origin: String,
        capability: HTMLAppCapability,
        reason: String,
        requestedScope: HTMLAppPermissionScope
    ) {
        self.appName = appName
        self.origin = origin
        self.capability = capability
        self.reason = reason
        self.requestedScope = requestedScope
    }
}

/// The user's answer on the branded panel. `authorized` carries the scope the
/// user chose, which may differ from the scope the HTML app requested.
public enum HTMLAppPermissionPromptOutcome: Equatable, Sendable {
    case authorized(scope: HTMLAppPermissionScope)
    case cancelled
}

/// Presents the branded first-layer consent panel. Implementations must call
/// the completion exactly once and support programmatic dismissal.
public protocol HTMLAppPermissionPromptPresenting: AnyObject {
    /// Returns `false` when no prompt could be presented (for example no host
    /// view controller); the completion still fires with `.cancelled`.
    @discardableResult
    func presentPrompt(
        for context: HTMLAppPermissionPromptContext,
        completion: @escaping (HTMLAppPermissionPromptOutcome) -> Void
    ) -> Bool

    /// Dismisses the visible prompt, resolving it as cancelled.
    func dismissActivePrompt()
}

public final class HTMLAppPermissionCoordinator {

    private final class RequestBox {
        let request: HTMLAppCapabilityRequest
        let documentURL: URL
        let completion: OnceResult

        init(
            request: HTMLAppCapabilityRequest,
            documentURL: URL,
            completion: @escaping (HTMLAppCapabilityResult) -> Void
        ) {
            self.request = request
            self.documentURL = documentURL
            self.completion = OnceResult(completion)
        }
    }

    private final class PromptGroup {
        let subject: HTMLAppPermissionSubject
        let capability: HTMLAppCapability
        let context: HTMLAppPermissionPromptContext
        var boxes: [RequestBox] = []
        /// Set when the subject is cancelled before or during presentation so a
        /// late main-queue presentation never shows a dead panel.
        var isCancelled = false

        init(subject: HTMLAppPermissionSubject, context: HTMLAppPermissionPromptContext, box: RequestBox) {
            self.subject = subject
            self.capability = context.capability
            self.context = context
            self.boxes = [box]
        }

        var groupKey: String {
            subject.storageKey(capability: capability)
        }
    }

    private let gateway: HTMLAppCapabilityGateway
    private let presenter: HTMLAppPermissionPromptPresenting
    private let lock = NSLock()
    private var activeGroup: PromptGroup?
    private var queuedGroups: [PromptGroup] = []

    public init(gateway: HTMLAppCapabilityGateway, presenter: HTMLAppPermissionPromptPresenting) {
        self.gateway = gateway
        self.presenter = presenter
    }

    public var hasActivePrompt: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeGroup != nil
    }

    /// Runs the full authorization flow for one bridge request. Terminal
    /// results (existing grant, system denial, manifest rejection) complete
    /// immediately; otherwise the branded panel is presented, queued behind a
    /// visible one, or merged into an identical pending request.
    public func authorize(
        subject: HTMLAppPermissionSubject,
        documentURL: URL,
        request: HTMLAppCapabilityRequest,
        appName: String,
        completion: @escaping (HTMLAppCapabilityResult) -> Void
    ) {
        let decision = gateway.requestAuthorization(subject: subject, documentURL: documentURL, request: request)
        guard decision.status == .notDetermined, decision.authorizationLayer == .htmlApp else {
            DispatchQueue.main.async { completion(decision) }
            return
        }

        let box = RequestBox(request: request, documentURL: documentURL, completion: completion)
        let context = HTMLAppPermissionPromptContext(
            appName: appName,
            origin: subject.origin,
            capability: request.capability,
            reason: request.reason,
            requestedScope: request.scope
        )

        var groupToPresent: PromptGroup?
        lock.lock()
        if let index = queuedGroups.firstIndex(where: { $0.groupKey == boxGroupKey(subject: subject, capability: request.capability) }) {
            queuedGroups[index].boxes.append(box)
        } else if let active = activeGroup, active.groupKey == boxGroupKey(subject: subject, capability: request.capability) {
            active.boxes.append(box)
        } else {
            let group = PromptGroup(subject: subject, context: context, box: box)
            if activeGroup != nil {
                queuedGroups.append(group)
            } else {
                activeGroup = group
                groupToPresent = group
            }
        }
        lock.unlock()

        if let group = groupToPresent {
            presentGroupOnMain(group)
        }
    }

    /// Cancels every pending prompt for one subject (container closing or the
    /// app navigating to another origin). A visible panel for the subject is
    /// dismissed; all merged completions resolve as user-cancelled exactly once.
    public func cancelPendingRequests(subject: HTMLAppPermissionSubject) {
        var cancelledActive: PromptGroup?
        var orphanedGroups: [PromptGroup] = []
        lock.lock()
        orphanedGroups = queuedGroups.filter { $0.subject == subject }
        queuedGroups.removeAll { $0.subject == subject }
        if let active = activeGroup, active.subject == subject {
            active.isCancelled = true
            activeGroup = nil
            cancelledActive = active
        }
        lock.unlock()

        // Queued and not-yet-presented groups resolve their boxes directly.
        var groupsToResolve = orphanedGroups
        if let active = cancelledActive {
            groupsToResolve.append(active)
        }
        for group in groupsToResolve {
            resolveBoxesAsCancelled(group)
        }

        if cancelledActive != nil {
            // If the panel did make it on screen, dismiss it. A late outcome
            // delivery finds empty boxes and completes nothing twice.
            presenter.dismissActivePrompt()
        }
        presentNextQueuedGroupIfNeeded()
    }

    // MARK: - Presentation

    private func presentGroupOnMain(_ group: PromptGroup) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            lock.lock()
            let cancelled = group.isCancelled
            lock.unlock()
            // The subject was cancelled while this presentation was queued.
            if cancelled {
                handleOutcome(.cancelled, for: group)
                return
            }

            let presented = presenter.presentPrompt(for: group.context) { [weak self] outcome in
                self?.handleOutcome(outcome, for: group)
            }
            if !presented {
                handleOutcome(.cancelled, for: group)
            }
        }
    }

    private func resolveBoxesAsCancelled(_ group: PromptGroup) {
        lock.lock()
        let boxes = group.boxes
        group.boxes = []
        lock.unlock()
        for box in boxes {
            gateway.resolveUserConsent(
                subject: group.subject,
                documentURL: box.documentURL,
                request: box.request,
                approvedScope: box.request.scope,
                granted: false
            ) { result in
                DispatchQueue.main.async { box.completion.perform(result) }
            }
        }
    }

    private func handleOutcome(_ outcome: HTMLAppPermissionPromptOutcome, for group: PromptGroup) {
        lock.lock()
        let boxes = group.boxes
        group.boxes = []
        if activeGroup === group {
            activeGroup = nil
        }
        queuedGroups.removeAll { $0 === group }
        lock.unlock()

        for box in boxes {
            switch outcome {
            case .cancelled:
                gateway.resolveUserConsent(
                    subject: group.subject,
                    documentURL: box.documentURL,
                    request: box.request,
                    approvedScope: box.request.scope,
                    granted: false
                ) { result in
                    DispatchQueue.main.async { box.completion.perform(result) }
                }
            case .authorized(let scope):
                gateway.resolveUserConsent(
                    subject: group.subject,
                    documentURL: box.documentURL,
                    request: box.request,
                    approvedScope: scope,
                    granted: true
                ) { result in
                    DispatchQueue.main.async { box.completion.perform(result) }
                }
            }
        }

        presentNextQueuedGroupIfNeeded()
    }

    private func presentNextQueuedGroupIfNeeded() {
        lock.lock()
        guard activeGroup == nil, !queuedGroups.isEmpty else {
            lock.unlock()
            return
        }
        let next = queuedGroups.removeFirst()
        activeGroup = next
        lock.unlock()

        presentGroupOnMain(next)
    }

    private func boxGroupKey(subject: HTMLAppPermissionSubject, capability: HTMLAppCapability) -> String {
        subject.storageKey(capability: capability)
    }
}

/// Wraps a completion so it can only fire once, regardless of how many code
/// paths (panel buttons, dismissal, cancellation) race to call it.
final class OnceResult: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((HTMLAppCapabilityResult) -> Void)?

    init(_ completion: @escaping (HTMLAppCapabilityResult) -> Void) {
        self.completion = completion
    }

    func perform(_ result: HTMLAppCapabilityResult) {
        lock.lock()
        let completion = completion
        self.completion = nil
        lock.unlock()
        completion?(result)
    }
}
