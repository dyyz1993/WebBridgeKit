# ADR-0002: Separate the SDK, starter template, and complete product app

## Status

Accepted

## Context

WebBridgeKit began with SDK infrastructure: WebView bridging, native handlers,
cache engines, message routing, diagnostics, and developer tooling. Those
capabilities were built to support development of a complete iOS application.

The repository also contains `AppTemplate` and an application target named
`SuperApp`. Earlier documentation sometimes called `SuperApp` an example app
and described `AppTemplate` as demonstrating the complete framework. That
language makes it unclear which target ordinary users should install and where
new functionality belongs.

The product now has a user-facing home, Inbox, PWA application center, message
details, Markdown rendering, Approval v1, and official/self-hosted onboarding.
These are product application concerns, not starter-template concerns.

## Decision

The repository maintains three distinct client deliverables:

1. **WebBridgeKit SDK (`Sources/`)** provides reusable native-enhanced PWA
   runtime capabilities. It owns generic Bridge, cache, message, routing,
   permission, security, and diagnostic contracts.
2. **AppTemplate (`AppTemplate/`)** is the minimum starting point for a team
   building another host application with the SDK. It demonstrates safe
   initialization and basic host wiring. It does not mirror the complete
   WebBridgeKit product UI.
3. **WebBridgeKit App (`SuperApp/`)** is the complete user-facing application
   built on the SDK. `SuperApp` remains the internal target name for now; it is
   not a maturity label and does not mean sample-only software.

The official hosted distribution and the open-source self-hosted distribution
use the same complete WebBridgeKit App. Self-hosting adds a one-time compatible
gateway import; it does not switch the user to AppTemplate.

Feature placement follows these rules:

- Cross-host runtime behavior belongs in the SDK.
- Minimum integration wiring belongs in AppTemplate.
- User journeys and product information architecture belong in SuperApp.
- Shared push, approval, and gateway service contracts belong in Server and
  `docs/api`.
- Showcase and diagnostic surfaces are secondary developer tools, not primary
  product navigation.

## Consequences

### Positive

- SDK development remains reusable and testable without forcing product UI on
  integrators.
- Developers receive a small template instead of copying a large official app.
- Ordinary and self-hosted users receive the same complete client experience.
- Product work can be evaluated by end-user readiness rather than framework
  feature count.

### Negative

- Documentation, tests, and release workflows must identify which deliverable
  they verify.
- AppTemplate requires a cleanup pass so test keys, permissive debug defaults,
  and showcase-heavy navigation are not presented as production defaults.
- The internal `SuperApp` name may remain visible in build tooling until a
  separate low-risk target-renaming migration is planned.

### Neutral

- This decision does not rename targets or move source files immediately.
- The SDK may include reusable UI components when they represent generic host
  behavior, but application-specific composition remains in SuperApp.

## Alternatives Considered

### Treat the complete application as only a template

Rejected. Ordinary users need an installable product with a stable home,
Inbox, PWA management, and settings. Requiring every deployment to assemble an
App from a template contradicts the official configuration-free path.

### Remove AppTemplate and tell developers to fork SuperApp

Rejected. Forking the full product creates unnecessary coupling to official
information architecture and makes SDK adoption harder to understand.

### Put all user-facing features into the SDK

Rejected. It would bind a reusable runtime to one product's navigation and
business presentation.

## References

- `README.md`
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/adr/0001-generic-html-app-runtime.md`
- `docs/plans/2026-08-12-official-selfhosted-onboarding-design.md`
