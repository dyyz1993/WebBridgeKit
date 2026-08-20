import Hummingbird

struct ApprovalRoutes {
    let services: ServiceRegistry

    func register(on router: Router<some RequestContext>) {
        router.get("/api/v1/approvals/:requestId") { request, context in
            guard let requestID = context.parameters.get("requestId") else {
                throw HTTPError(.badRequest, message: "Missing requestId")
            }
            let deviceKey = try Self.deviceKey(from: request)
            return try await services.approvalStore.status(requestID: requestID, deviceKey: deviceKey)
        }

        router.post("/api/v1/approvals/:requestId/respond") { request, context in
            guard let requestID = context.parameters.get("requestId") else {
                throw HTTPError(.badRequest, message: "Missing requestId")
            }
            let deviceKey = try Self.deviceKey(from: request)
            let submission = try await request.decode(as: ApprovalResponseSubmission.self, context: context)
            let record = try await services.approvalStore.respond(
                requestID: requestID,
                deviceKey: deviceKey,
                submission: submission
            )
            if record.configuration.responseMode == "webhook" {
                Task {
                    await services.approvalWebhookService.deliver(record: record)
                }
            }
            let fallbackPayload = PushPayload(
                schema: "webbridgekit.message.v1",
                type: "approval",
                title: record.title,
                body: record.body,
                category: "approval",
                replacementID: record.messageID,
                actionState: record.state.rawValue,
                requestID: record.requestID,
                contentType: "approval",
                revision: record.revision,
                presentation: "native"
            )
            let statusPayload = record.clientPayload?.updatingApprovalState(
                record.state,
                revision: record.revision
            ) ?? fallbackPayload
            _ = try? await services.apnsService.sendPush(key: record.deviceKey, payload: statusPayload)
            return ApprovalStatusResponse(record: record)
        }
    }

    private static func deviceKey(from request: Request) throws -> String {
        guard let authorization = request.headers[.authorization],
              authorization.hasPrefix("Bearer "),
              !authorization.dropFirst(7).isEmpty else {
            throw HTTPError(.unauthorized, message: "Missing device key")
        }
        return String(authorization.dropFirst(7))
    }
}
