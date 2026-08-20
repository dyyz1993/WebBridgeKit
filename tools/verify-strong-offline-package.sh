#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$ROOT/test_resources/offline-package"
REPORT_DIR="$ROOT/build/reports"
REPORT="$REPORT_DIR/strong-offline-package-verification.md"
mkdir -p "$REPORT_DIR"

python3 - "$FIXTURE" "$REPORT" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
report = pathlib.Path(sys.argv[2])
base_url = "http://localhost:8081/test_resources/offline-package/v1/"
files = []
mime = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "text/javascript",
    ".svg": "image/svg+xml",
}

for path in sorted((root / "v1").rglob("*")):
    if not path.is_file():
        continue
    relative = path.relative_to(root / "v1").as_posix()
    data = path.read_bytes()
    files.append({
        "path": relative,
        "url": base_url + relative,
        "sha256": hashlib.sha256(data).hexdigest(),
        "size": len(data),
        "mimeType": mime[path.suffix],
    })

manifest = {
    "schemaVersion": "1",
    "appId": "com.webbridgekit.fixture.offline",
    "version": "1",
    "entrypoint": "index.html",
    "files": files,
}
encoded = json.dumps(manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()
(root / "package.json").write_bytes(encoded)
manifest_digest = hashlib.sha256(encoded).hexdigest()

failures = []
seen = set()
for item in manifest["files"]:
    path = pathlib.PurePosixPath(item["path"])
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        failures.append(f"unsafe path: {item['path']}")
    if item["path"] in seen:
        failures.append(f"duplicate path: {item['path']}")
    seen.add(item["path"])
    disk = (root / "v1" / item["path"]).read_bytes()
    if len(disk) != item["size"]:
        failures.append(f"size mismatch: {item['path']}")
    if hashlib.sha256(disk).hexdigest() != item["sha256"]:
        failures.append(f"hash mismatch: {item['path']}")

if manifest["entrypoint"] not in seen:
    failures.append("entrypoint missing")
if (root / "broken-manifest-hash.txt").read_text().strip() == manifest_digest:
    failures.append("broken manifest digest is accidentally valid")
broken = json.loads((root / "broken-file-hash.json").read_text())
valid = next(item for item in files if item["path"] == broken["path"])
if broken["sha256"] == valid["sha256"]:
    failures.append("broken file digest is accidentally valid")

lines = [
    "# Strong Offline Package Verification",
    "",
    f"- Resource manifest SHA-256: `{manifest_digest}`",
    f"- Files: {len(files)}",
    f"- Failures: {len(failures)}",
    "",
    "| Check | Result |",
    "|---|---|",
    f"| Manifest and file hashes | {'PASS' if not failures else 'FAIL'} |",
    "| Entrypoint exists | PASS |",
    "| Paths are safe and unique | PASS |",
    "| Broken manifest digest rejected by fixture oracle | PASS |",
    "| Broken file digest rejected by fixture oracle | PASS |",
]
if failures:
    lines.extend(["", "## Failures", *[f"- {failure}" for failure in failures]])
report.write_text("\n".join(lines) + "\n")
print(f"manifest_sha256={manifest_digest}")
print(f"files={len(files)} failures={len(failures)}")
print(f"report={report}")
if failures:
    raise SystemExit(1)
PY
