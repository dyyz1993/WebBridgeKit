import Foundation
import Hummingbird

enum CommandRoutes {
    static func register(on router: Router<some RequestContext>, services: ServiceRegistry) {
        let apiGroup = router.group("api/v1/commands")

        apiGroup.post { request, context in
            let commandRequest = try await request.decode(as: CommandGenerateRequest.self, context: context)
            return try await services.commandService.generate(request: commandRequest)
        }

        apiGroup.get("/:id") { _, context in
            guard let id = context.parameters.get("id") else {
                throw HTTPError(.badRequest, message: "Missing command id")
            }
            return try await services.commandService.resolve(id: id)
        }
    }
}
