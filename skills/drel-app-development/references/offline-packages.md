# Strong offline packages

Use strong offline mode only when the user needs a web app to remain launchable
after the network and normal WebKit cache are unavailable.

## Files and trust chain

1. A **signed Drel parent manifest** sets a stable `appId`, version,
   `resourceManifestURL`, and `resourceManifestSHA256`.
2. A standard `manifest.webmanifest` may declare the matching extension:

```json
"drel_offline": {
  "version": "1",
  "resource_manifest": "https://example.com/app/package.json",
  "resource_manifest_sha256": "64-lowercase-hex-characters"
}
```

3. The exact `package.json` bytes list each resource, its HTTPS source, byte
   size, MIME type and SHA-256:

```json
{
  "schemaVersion": "1",
  "appId": "com.example.console",
  "version": "1",
  "entrypoint": "index.html",
  "files": [{
    "path": "index.html",
    "url": "https://example.com/app/v1/index.html",
    "sha256": "64-lowercase-hex-characters",
    "size": 1234,
    "mimeType": "text/html"
  }]
}
```

## Publish an update

- Publish new immutable URLs such as `/app/v2/...`; never replace the bytes at
  a URL used by a prior version.
- Hash every new file, serialize the resource manifest, hash the exact manifest
  bytes, then update and sign the parent manifest.
- Drel downloads to a private staging directory, validates every file, then
  atomically switches the active pointer. It preserves the previous complete
  version until the new version is valid.
- The user must tap **Update offline package**. A push, background task or
  remote page may indicate that an update exists but may not install it.

## What remains online

Only listed static files become local. `fetch()` calls, third-party scripts,
CDNs, APIs, dynamic media and authentication still require network access.
The page must handle network failure without blanking or claiming stale data is
live. Persisting a clearly labelled last successful result is acceptable.

## Limits and safety

Use relative POSIX paths only. No empty paths, `..`, absolute paths,
backslashes, duplicate paths, redirects, cross-origin resources or arbitrary
local file paths. Current default limits are 2,000 files, 50 MiB per file and
250 MiB total; a host can impose lower limits.

See `docs/api/offline-package-v1.md` for the full contract.
