# WebBridgeKit Strong Offline Package v1

## Purpose

This contract lets a trusted HTML app remain launchable after the network and
WebKit cache are unavailable. It is an installation contract, not an approval
or command-execution channel.

## Trust chain

1. The gateway verifies the Ed25519 signature on the parent `HTMLAppManifest`.
2. The signed parent `cache.resourceManifestSHA256` pins the exact resource
   manifest bytes.
3. The resource manifest pins every file by path, byte size, and SHA-256.
4. The native installer activates a version only after every check succeeds.

Push data may select `appId + route + parameters`, but package content must not
automatically approve or execute a sensitive action.

## Parent cache policy

```json
{
  "strategy": "manifest",
  "version": "42",
  "persistent": true,
  "resourceManifestURL": "https://example.com/apps/demo/package.json",
  "resourceManifestSHA256": "64-lowercase-hex-characters"
}
```

Strong-offline eligibility requires all five fields. A legacy manifest without
`resourceManifestSHA256` remains valid and uses the partial-cache path; it must
not be displayed as strongly offline.

## Resource manifest

```json
{
  "schemaVersion": "1",
  "appId": "com.example.demo",
  "version": "42",
  "entrypoint": "index.html",
  "files": [
    {
      "path": "index.html",
      "url": "https://example.com/apps/demo/index.html",
      "sha256": "64-lowercase-hex-characters",
      "size": 1234,
      "mimeType": "text/html"
    }
  ]
}
```

`appId` and `version` must exactly equal the signed parent values. The
entrypoint must appear once in `files`. Paths are POSIX-style relative paths;
absolute paths, empty segments, `.`, `..`, backslashes, duplicate paths, and
file/directory collisions are rejected. URLs must use an allowed HTTPS origin.
Debug-only localhost HTTP fixtures require an explicit installer option.

The default limits are 1 MiB for the resource manifest, 2,000 files, 50 MiB per
file, and 250 MiB total. Hosts may lower these limits.

## Publishing

1. Produce immutable files for a new version.
2. Compute each file's byte count and lowercase SHA-256.
3. Serialize the resource manifest as the exact bytes to be served.
4. Compute the resource manifest SHA-256.
5. Put that digest and the immutable resource manifest URL in the parent
   manifest, then sign the parent manifest.
6. Never mutate bytes at a published version URL. Publish a new version.

The deterministic fixture generator is:

```bash
bash tools/verify-strong-offline-package.sh
```

## Error semantics

The SDK reports typed `HTMLAppOfflinePackageError` values for parent
ineligibility, manifest/file digest mismatch, identity mismatch, unsafe path,
disallowed origin or redirect, quota violation, size mismatch, transport
failure, and persistence failure. No partial staging directory becomes active.

## Migration

- Existing network-only manifests remain network-only.
- Existing persistent resource manifests without a digest remain partial.
- Adding a valid digest makes a parent eligible, not installed. The launch
  resolver reports strong mode only after a matching complete version exists.
- Removing or changing the digest does not authorize an old package for a new
  parent manifest.
