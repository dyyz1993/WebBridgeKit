# Drel brand contract

> Status: Approved product identity; collision screening remains conditional  
> Owner: WebBridgeKit project owner  
> Last verified: 2026-08-26  
> Canonical for: product naming, copy, domains, store identity, logo, and promotion

## Product Identity

- **Public name:** Drel
- **Pronunciation:** “drell”, one syllable
- **Syllable count:** One
- **Chinese name:** No official Chinese product name has been approved.
- **Chinese naming policy:** English-only official brand for the current release;
  localize the category descriptor, slogan, and supporting copy. A future
  Chinese official name or nickname requires explicit approval and separate
  App Store, web, and trademark screening.
- **Product type:** iOS developer notification utility and trusted web-tool container
- **Related open-source identity:** WebBridgeKit
- **Identity boundary:** Drel is the end-user product. WebBridgeKit remains the
  repository, reusable SDK/runtime, Swift import identity, Bridge/API vocabulary,
  custom scheme family, and self-hosted gateway contract unless a separately
  versioned migration is approved.
- **Attribution:** Built with WebBridgeKit.

## Positioning

- **Audience:** Developers using scripts, automations, services, and their own
  HTML/PWA tools.
- **Problem:** A push can alert a developer, but ordinary notifications do not
  give developer-owned web tools a clear native destination and exact route.
- **Promise:** Send a push and open the intended web tool and route in a trusted
  native home.
- **Category:** Developer push and web tools.
- **One-sentence positioning:** Drel is a native home for developers’
  notifications and trusted web tools.
- **Not positioned as:** A consumer notification app, general-purpose browser,
  public mini-app marketplace, or remote webpage-to-native Bridge product in
  the first Store release.

## Naming Decision

### Rationale

Drel is short, visually compact, and read as one stable English syllable. Its
invented spelling provides a distinct product label without renaming the
WebBridgeKit foundation. The name is interpreted as a concise arrival-oriented
brand rather than as a historical word or claimed etymology.

### Pronunciation and spelling

- Preferred pronunciation: “drell”, rhyming approximately with “shell”.
- Phonetic guide: `/drɛl/`.
- Preferred capitalization: `Drel` in prose; `drel.app` and `api.drel.app` for
  domains.
- Common misspellings to monitor: Drell, Dreal, Driel, DREL.
- Language note: Keep the Latin spelling Drel in every storefront; localize the
  supporting copy, not the product name.

### Rejected finalists

| Candidate | Status | Rejection reason | Evidence date |
| --- | --- | --- | --- |
| Relio | blocked | An existing App Store product uses the exact name. | 2026-08-24 |
| KOVR | blocked | An existing App Store product uses the exact name. | 2026-08-24 |

## Slogan and Copy

- **Primary slogan:** Push, right where you need it.
- **Supporting line:** A native home for your web apps and notifications.
- **Short description:** Developer push and trusted web tools, in one native home.
- **Attribution:** Built with WebBridgeKit.

### Channel variants

| Channel | Approved copy |
| --- | --- |
| Website hero | Push, right where you need it. |
| App Store promotional text | Push, right where you need it. |
| App Store subtitle | Developer Push & Web Tools |
| Social bio | A native home for developers’ web apps and notifications. |
| Chinese promotional text | 把推送送到真正该出现的地方。 |

Long-form App Store copy is maintained in
`docs/release/app-store-metadata.md`. Review-facing behavior is maintained in
`docs/app-store-review-notes.md`.

## Logo and Visual Identity

### Concept

The approved mark is an open D-shaped route. The incoming blue dot represents a
message; the blue-to-violet route represents its reliable arrival in a native
home. The open form reinforces navigation and delivery without turning the mark
into a generic bell, browser globe, shield, or checkmark.

### Palette

| Token | Value | Usage |
| --- | --- | --- |
| Route blue | `#4F6AF6` | Incoming message and gradient start |
| Route violet | `#8B5CF6` | Route and gradient end |
| Cool white | product canvas token | Primary light canvas |
| Product ink | product text token | Wordmark and supporting type |

Native product surfaces must consume the project design tokens rather than
copying these hex values into UI code.

### Construction and usage

- Clear space: keep at least 10% of the mark width on every side.
- Minimum digital size: 24 px for the mark; use a simplified approved export
  below 32 px and inspect it at 16 px for favicon use.
- Approved backgrounds: cool white/light canvas, approved dark surface with a
  reverse variant, or a controlled monochrome treatment.
- Small-size behavior: preserve the open route and incoming dot; do not retain
  decorative detail that closes the counter or merges the dot into the route.
- App icon: use a lossless RGB master without alpha, do not pre-round corners,
  and preserve optical padding for Apple’s mask.
- Prohibited uses: stretching, rotation, recoloring outside approved variants,
  adding shadows/outline/3D effects, enclosing the mark in another symbol, or
  replacing functional Lucide icons with the Drel mark.

### Required variants

- Primary blue-to-violet mark on light canvas.
- Reverse mark for dark backgrounds.
- One-color light and dark marks.
- Small-size favicon/social-avatar mark.
- iOS app-icon export set.

The current approved source is a 1254 × 1254 RGB PNG. Preserve it losslessly;
do not regenerate future assets from compressed screenshots. A reproducible
vector/construction source remains a recommended follow-up asset.

## Asset Map

| Asset | Path | Role | Status |
| --- | --- | --- | --- |
| App icon master | `SuperApp/Resources/branding/drel-app-icon-master.png` | Canonical raster source | approved |
| Native product mark | `SuperApp/Sources/Assets.xcassets/DrelBrand.imageset` | App UI identity | approved |
| iOS icon set | `SuperApp/Sources/Assets.xcassets/AppIcon.appiconset` | Generated device/store exports | approved |
| Node admin mark | `Server/node/drel-mark.png` | Product-facing admin surface | approved derivative |
| Website mark | `docs/site/assets/drel-mark.svg` | Public website identity | approved web source |
| Store screenshots | `docs/screenshots/` | App Store media | draft; recapture from final TestFlight build |

Legacy `webbridgekit-*` assets remain valid for the SDK/open-source identity and
must not be deleted as part of Drel product branding.

## Domain and Store Screening

### Current identity records

| Surface | Value | Ownership / state | Last verified |
| --- | --- | --- | --- |
| Product domain | `drel.app` | Registered by the project; Cloudflare Pages active; HTTPS 200 | 2026-08-26 |
| Official API | `api.drel.app` | Cloudflare Worker/proxy active; `/health` reports ok | 2026-08-26 |
| Public App Store exact-name screen | `Drel` | No exact result in US, CN, CA, or GB Apple Search API | 2026-08-26 |
| App Store Connect name acceptance | `Drel` | Must be read back from the actual app/version record before submission | 2026-08-26 |
| Bundle ID | `com.webbridgekit.superapp` | Retained internal compatibility identity | 2026-08-26 |

### Screening evidence

| Surface | Query / market | Checked at | Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| App Store | exact `Drel` / US, CN, CA, GB | 2026-08-26 | Zero exact public results; near result `DREO` observed | verified-clear-for-current-screen | Apple public Search API by storefront |
| Domain | `drel.app` | 2026-08-26 | Project domain serves the official site over HTTPS | verified-clear-for-current-screen | `https://drel.app/` and Cloudflare project state |
| API domain | `api.drel.app` | 2026-08-26 | Public health endpoint returns status ok | verified-clear-for-current-screen | `https://api.drel.app/health` |
| Web/company | exact Drel | 2026-08-26 | An unrelated active service uses `drel.ai` | conditional | `https://drel.ai/` |
| Trademark | Drel and phonetic variants / launch jurisdictions and relevant classes | 2026-08-26 | No complete official-database report is stored | unverified | WIPO and applicable national/regional searches required |
| GitHub/packages/social | Drel and variants | 2026-08-26 | No complete cross-registry report is stored | unverified | Live checks required before material launch spend |

### Remaining human or legal checks

- Re-run App Store public searches immediately before submission and verify that
  the App Store Connect product/version record actually saves and displays Drel.
- Review the active `drel.ai` usage for market and trademark overlap; domain
  ownership alone does not resolve this risk.
- Search WIPO and the official trademark databases for every launch market and
  relevant class; obtain qualified trademark advice before filing or major
  promotional spend.
- Check GitHub organizations, relevant package registries, and launch-channel
  social handles if they will be claimed.

No entry in this document is legal advice or a guarantee of global uniqueness.

## Promotion

### Launch kit

| Deliverable | Path / URL | Status | Notes |
| --- | --- | --- | --- |
| Product website | `docs/site/`, `https://drel.app/` | live | Homepage, Support, and Privacy are public |
| App Store metadata | `docs/release/app-store-metadata.md` | reviewed handoff | Remote saved state still requires read-back |
| App Review notes | `docs/app-store-review-notes.md` | prepared | Must match the exact submitted build |
| Support page | `https://drel.app/support/` | live | Uses `support@drel.app` |
| Privacy page | `https://drel.app/privacy/` | live | Uses `privacy@drel.app` |
| Screenshot set | `docs/screenshots/` | pending final capture | Capture from the final TestFlight build with no secrets/debug data |
| Social avatar/share image | not yet canonical | pending | Produce approved square avatar and 1200 × 630 share image |
| Press/launch cover | not yet canonical | pending | Keep claims within shipped 1.0 scope |

## Usage Rules

### Always

- Use Drel for end-user product surfaces and WebBridgeKit for the reusable SDK,
  runtime, repository, and open-source attribution.
- Use the approved pronunciation, slogan, positioning, palette, and Asset Map.
- Keep the first App Store release container-only: push and trusted web
  container, without remote webpage-to-native Bridge behavior.
- Re-run live collision checks before name reservation, registration, filing,
  launch, or material marketing spend.
- Record external mutations and verify their saved/active state afterward.

### Never

- Claim Drel is globally unique or trademark-safe from domain ownership or a
  zero-result public App Store search.
- Rename WebBridgeKit imports, APIs, schemes, repository identity, or gateway
  contracts merely to make product copy look consistent.
- Use the brand mark as a generic function icon.
- Publish device tokens, private push addresses, test data, debug screens, or
  unshipped Bridge capabilities in promotion or App Store media.

## Change Control

Before changing the Drel name, slogan, domains, store identity, logo, palette,
or canonical asset paths:

1. Update this contract and its verification date.
2. Re-run the relevant live App Store, domain, trademark, and broader collision
   checks.
3. Classify effects on display names, internal identifiers, bundle/package IDs,
   domains, schemes, APIs, legal names, attribution, and compatibility aliases.
4. Update the `AGENTS.md` reference if this document moves.
5. Run the `product-brand-launch` validation script.
6. Record any registration, DNS, App Store Connect, or publication mutation and
   read back the resulting state.
