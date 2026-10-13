# ADR-0006: Decouple and split the Drel product into a separate repository

## Status

Accepted

## Context

The repository currently carries three deliverables (WebBridgeKit SDK,
AppTemplate, SuperApp) plus the Drel self-hosted server, the product website
(`docs/site/`), the third-party developer skill (`skills/drel-app-development/`),
and App Store release tooling. The code dependency direction is clean and
one-way: SuperApp imports WebBridgeKit in 30+ files; no SDK source imports or
references any product symbol. `AppTemplate` already proves the SDK can be
consumed by a third-party host without the product.

However, product artifacts have leaked into the SDK layer (`Sources/`):

1. **Branded wire formats frozen in SDK code.** `drel_offline` manifest key
   (`HTMLAppRuntimeModels.swift`), the `drel://app` deep link
   (`DrelExternalAppLink.swift`), `drel_app_id` / `drel_route` / `drel_param_*`
   query parameters (`HTMLAppLaunchRuntime.swift`), and the
   `drel.push-envelope.v1` push envelope (`SelfHostedPushCrypto.swift`). These
   shipped in 1.0/1.4 and are consumed by the server, the notification service
   extension, and third-party template pages simultaneously.
2. **Product trust configuration hardcoded in SDK.**
   `HTMLAppGatewayConfiguration.swift` hardcodes the official gateway
   (`id: "drel-gateway"`, `baseURL: "https://api.drel.app"`), its trust anchor
   public key, and a migration path that moves user configs onto the official
   gateway.
3. **Product capability switch coupled to the framework target.** The
   `DREL_CONTAINER_ONLY` compilation condition is defined both on the
   WebBridgeKit framework target and on the SuperApp app target in
   `project.yml`. A separately distributed SDK Release build would silently
   become container-only, contradicting the documented intent that the
   reusable SDK remains bridge-capable by default.
4. **Product identifiers hardcoded in SDK.** `PushCipher.swift` and
   `SelfHostedPushCrypto.swift` hardcode the app group
   `group.com.webbridgekit.superapp` and the Keychain service
   `com.webbridgekit.superapp.push-crypto`. Any other host integrating the SDK
   collides with these. Additionally, `NotificationServiceExtension/PushCrypto.swift`
   hand-copies the envelope protocol constants, creating a second source of
   truth.

The practical pain today is release cadence: any SDK change must ride a Drel
App Store review, and the SDK cannot be branded, versioned, or open-sourced
independently.

## Decision

The Drel product (SuperApp app target, UI tests, notification service
extension, server, product website, developer skill, and release tooling) will
move to a separate repository. The split is executed in two phases.

### Phase 1 — De-coupling inside the current repository (prerequisite)

- `HTMLAppGatewayDefaults.official` (base URL, trust anchor, migration logic)
  moves out of the SDK. SuperApp injects its official gateway at startup; the
  SDK keeps only the generic gateway registry.
- `DREL_CONTAINER_ONLY` is removed from the WebBridgeKit framework target's
  Release configurations. Container-only behavior for the Store product is
  expressed by the app target's configuration only (or by an injected policy),
  so the independently built SDK remains bridge-capable by default.
- App Group and Keychain identifiers in `PushCipher` and `SelfHostedPushCrypto`
  become parameters supplied by the host. SDK defaults use its own namespace.
- The notification service extension stops hand-copying protocol constants and
  consumes a single shared definition (SDK Message framework or a shared spec).

### Phase 2 — Physical split

- **Moves to the Drel product repository:** `SuperApp/`,
  `SuperAppUITests/`, `NotificationServiceExtension/`, `Server/` (entirely;
  it shares no code with the SDK), `skills/drel-app-development/`,
  `docs/site/`, the product-specific API docs (`docs/api/drel-*.md`), the ~16
  drel-specific scripts and fixtures under `tools/`, the `build-ipa` and
  `deploy-drel-api-proxy` workflows, and App Store signing configuration.
- **Stays in the WebBridgeKit repository:** `Sources/`, `Tests/`,
  `AppTemplate/`, generic engineering tools and CI (architecture/design lint),
  generic protocol docs (`gateway-v1`, `push-v2`, `offline-package-v1`,
  `message-types-v1`, `approval-v1`), and ADR-0001.
- **Wire format decision:** the `drel_`-prefixed protocol namespace stays as-is
  in the SDK, documented as a frozen v1 protocol. Renaming it would break
  deployed servers, extensions, and template pages for no functional gain; the
  product repository references the protocol docs in the SDK repository.
- The product repository gets its own xcodegen project, Podfile (Kingfisher and
  other product-only pods split out; RxSwift/Realm/SnapKit stay SDK-side where
  they are real dependencies), and CI. The legacy nested
  `SuperApp/project.yml` is deleted before the split.

## Consequences

### Positive

- SDK and product release independently; SDK fixes no longer require an App
  Store review cycle.
- The SDK becomes genuinely brand-neutral, matching the ADR-0001 commitment
  that product integrations stay out of the framework core.
- Third-party hosts no longer collide with hardcoded app groups or inherit the
  official Drel gateway by default.
- CI responsibilities become clear: SDK repo runs architecture/design lint and
  unit tests; product repo runs UI tests, IPA builds, and proxy deploys.

### Negative

- Cross-cutting protocol changes now require synchronized releases in two
  repositories.
- The product repository must rebuild its own workspace topology (the current
  Podfile `inherit! :search_paths` arrangement disappears with the workspace).
- Protocol drift risk between the SDK and the server increases without a
  deliberate spec-review process across repositories.

### Neutral

- `drel_`-prefixed wire formats remain in SDK code and docs as a frozen
  protocol namespace; this is a naming artifact, not a dependency.
- Some SuperAppUITests suites (debug panel, cache dashboard) exercise SDK
  behavior through the product; they stay with the product as integration
  coverage.

## Alternatives Considered

### Keep the monorepo with existing target isolation

Rejected. Target isolation already exists, but the release-cadence coupling and
brand leakage remain: every SDK change rides an App Store review, and the
distributed SDK Release configuration is container-only.

### Extract a third protocol-spec repository

Deferred. The protocol docs living in the SDK repository with the product
repository referencing them is sufficient at current scale; a dedicated spec
repo adds process overhead without reducing coupling further.

### Rename the wire format to a neutral prefix (e.g. `wbk_`)

Rejected. `drel_offline`, `drel://app`, and `drel.push-envelope.v1` are already
deployed across the server, the shipped extension, and third-party template
pages. A rename breaks compatibility across three ends for no functional gain.

## References

- `docs/adr/0001-generic-html-app-runtime.md` (generic runtime commitment)
- `docs/adr/0002-sdk-template-product-app-boundary.md` (deliverable boundaries)
- `Sources/Runtime/HTMLAppGatewayConfiguration.swift` (hardcoded official gateway)
- `Sources/Runtime/DrelContainerBuildPolicy.swift` (container-only policy)
- `Sources/Message/PushCipher.swift`, `Sources/Message/SelfHostedPushCrypto.swift`
  (app group / keychain hardcoding)
- `project.yml` (framework/app target configuration coupling)
- `docs/plans/2026-08-28-drel-phased-release-roadmap.md` (product scope)
