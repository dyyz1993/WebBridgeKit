# Drel 1.4 public strong-offline fixture

## Stable public artifacts

- Test landing page: `https://drel.app/test/offline/`
- Online entry page: `https://drel.app/test/offline/v1/index.html`
- Web App Manifest: `https://drel.app/test/offline/manifest.webmanifest`
- Drel resource manifest: `https://drel.app/test/offline/package.json`
- Diagnostic ZIP: `https://drel.app/test/offline/drel-offline-demo-v1.zip`
- Signed gateway entry: `https://api.drel.app/api/v1/html-apps`
- App ID: `dev.drel.offline-demo`

The ZIP is a manual inspection and future archive-transport fixture. Drel 1.4
does not execute it directly. The runtime installs the resource manifest's
individual files, validates every size and SHA-256 digest, then atomically
activates the private package directory.

## Reproduce the website package

```bash
bash tools/build-drel-offline-demo-site.sh
bash tools/verify-drel-offline-demo-public.sh
```

`build/drel-site-staging/test/offline/gateway-manifest.json` is the unsigned
operator input. The official gateway validates and signs it with its existing
server-side Ed25519 key. The signing key must never be copied into the site,
ZIP, repository or client.

## Verified on 2026-09-09

- Public package SHA-256:
  `cae64b9e21c586dfabe0d5212ad5a144a380895bc524e6e94f639b8dfdef5c1b`
- Public Web App Manifest SHA-256:
  `8c03587a102a42c4c4b7eb24094ff37901490bd5318177a94d4ba8d8903d527b`
- Four package resources downloaded from `drel.app`; every size and digest matched.
- ZIP contained the versioned page, resource manifest and Web App Manifest.
- Official gateway returned two signed apps and preserved `webManifest`,
  `drel_offline` and `cache.resourceManifestSHA256` for the offline demo.
- Fresh Drel 1.4 simulator install imported `dev.drel.offline-demo`, downloaded
  the package and changed the action from “下载离线包” to “更新离线包”.
- “打开应用” loaded the verified local entry from
  `Application Support/WebBridgeKit/Packages/.../index.html`; the rendered
  page is captured at `build/reports/drel-14-public-offline-demo.png`.
- The signed Web App Manifest now declares a PNG icon. A Release simulator
  retained it under `Application Support/WebBridgeKit/AppIcons`, displayed the
  real Drel mark for the offline demo, and kept the release monitor on the
  expected name-initial fallback because that app declares no icon. Existing
  installs refresh presentation metadata when the signed binding digest
  changes.
- `ModelsTests`: 291 passed; `CacheTests`: 562 passed; server: 70 passed.
- Drel 1.4 boundary: 15 passed; container-only boundary: 38 passed.

## Defects found by the public flow

1. Server source previously did not preserve and sign the new Web Manifest and
   `drel_offline` fields. The model, persistence, signature and validation path
   now cover them.
2. Host launch resolvers previously created private registry snapshots before
   first-run gateway onboarding, so a newly imported app appeared in the UI but
   could not launch. All host resolvers now use the live shared trust registry.
3. The first fixture used a `*` route although the iOS route contract supports
   exact segments and named `:parameters`, not glob wildcards. The public entry
   now uses the exact route and the server rejects unsupported wildcards.
4. A downloaded package could resolve to the correct `file://` entrypoint but
   one host path still passed it through a regular URL request or the legacy
   manifest loader. Installed packages now always use `WKWebView.loadFileURL`
   with read access to the query-free package directory; simulator rendering
   and runtime logs confirm the page and relative resources load locally.
5. Download progress and failure status reused one overlay window while adding
   a new toast container for every transition. HUD status replacement now
   removes the prior container and guards stale dismiss animations, so rapid
   offline failures display exactly one message.

## Remaining physical-device evidence

The simulator and public origin prove onboarding, download, integrity,
installation and local-path launch. Before shipping 1.4, repeat download,
airplane-mode cold launch, relaunch after termination, interrupted update,
rollback and disk-pressure retention on a physical TestFlight device using
`docs/verification/drel-14-physical-device.md`.
