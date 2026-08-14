import Hummingbird

struct HTMLAppGatewayRoutes {
    let services: ServiceRegistry

    func register(on router: Router<some RequestContext>) {
        router.get("api/v1/gateway") { _, _ in
            try await services.htmlAppGatewayService.gatewayConfiguration()
        }

        let appGroup = router.group("api/v1/html-apps")
        appGroup.get { _, _ in
            try await services.htmlAppGatewayService.list()
        }
        appGroup.get("/:appId") { _, context in
            guard let appID = context.parameters.get("appId") else {
                throw HTTPError(.badRequest, message: "Missing appId")
            }
            return try await services.htmlAppGatewayService.get(appID: appID)
        }
        appGroup.post { request, context in
            let manifest = try await request.decode(as: HTMLAppPolicyManifest.self, context: context)
            return try await services.htmlAppGatewayService.save(manifest)
        }
        appGroup.delete("/:appId") { _, context in
            guard let appID = context.parameters.get("appId") else {
                throw HTTPError(.badRequest, message: "Missing appId")
            }
            try await services.htmlAppGatewayService.remove(appID: appID)
            return HTTPResponse.Status.noContent
        }
    }
}
