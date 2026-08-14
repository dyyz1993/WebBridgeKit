# Strong Offline HTML App Packages

## Boundary

`Sources/` owns the generic package protocol, installer, locator, and launch
resolution. Product UI remains in `SuperApp/`. AppTemplate is unchanged.

## Storage layout

Active packages use application-managed persistent storage:

```text
Library/Application Support/WebBridgeKit/Packages/
  <sha256(appId)>/
    current.json
    versions/
      <sha256(version)>-<manifest-digest-prefix>/
        package.json
        index.html
        assets/...
```

The root is excluded from iCloud backup and uses complete-until-first-unlock
file protection. App state snapshots remain under `WebBridgeKit/AppState`; a
package update cannot erase page state. WebKit cache and `Library/Caches` are
never authoritative for strong availability.

## Installation transaction

```text
verify trusted parent policy
  -> download bounded resource manifest
  -> verify parent-pinned manifest SHA-256
  -> validate schema, identity, paths, origins, and quotas
  -> create random staging directory
  -> download each bounded file
  -> verify size and SHA-256
  -> write local package metadata
  -> move complete staging directory into versions/
  -> atomically replace current.json
  -> remove inactive versions
```

Before `current.json` changes, every error deletes only staging. The previous
pointer and complete directory remain launchable. If an online update fails,
the loader reports `usingPreviousVersion`; it does not replace the page with a
blank network error.

The pointer is a tiny atomically written file instead of a symlink. Package
paths cannot create symlinks because all content is written as newly created
regular files beneath a private staging root.

## Launch behavior

`HTMLAppLaunchResolver` distinguishes eligibility from availability:

- `networkOnly`: parent uses the network-only strategy.
- `partial`: old cache behavior, an eligible package not yet installed, or a
  locally installed version that does not match the current parent digest.
- `strong`: a complete installed package matches `appId`, `version`, and the
  parent resource-manifest digest.

For strong mode, `loaderURL` is the local entrypoint file. The existing WebView
file/custom-scheme path can serve sibling CSS, JavaScript, and image resources
without a network request. Updates are separate from launching: callers should
open the installed version immediately and schedule verification/install work
without blocking that launch.

## Failure and concurrency properties

- Manifest hash failure occurs before staging activation.
- File size/hash failure, connection interruption, and filesystem errors leave
  the previous pointer unchanged.
- Path traversal, cross-origin URLs, and cross-origin redirects fail before a
  file is trusted.
- One installer actor serializes installs submitted through it. Multiple
  installer instances use unique staging/version directories and atomic pointer
  writes, so the pointer can only reference a complete directory.
- A matching local package is never considered approval or authorization; all
  sensitive actions still require current server validation and user consent.

## Verification

Run the deterministic fixture oracle and cache regression:

```bash
bash tools/verify-strong-offline-package.sh
bash tools/run-cache-regression.sh
```

The fixture contains HTML, CSS, JavaScript, and SVG plus intentionally invalid
manifest/file digests. Unit tests use injected transports and temporary package
roots, so hash, network, disk, rollback, and origin cases do not require the
public internet.
