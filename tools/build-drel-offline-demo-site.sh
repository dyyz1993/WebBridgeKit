#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/test_resources/offline-package/v1"
STAGE="${1:-$ROOT/build/drel-site-staging}"
PUBLIC_ROOT="https://drel.app/test/offline"
APP_ID="dev.drel.offline-demo"
VERSION="2"

case "$STAGE" in
  "$ROOT"/build/*) ;;
  *) echo "Refusing to replace a staging directory outside $ROOT/build" >&2; exit 2 ;;
esac

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$ROOT/docs/site/." "$STAGE/"
mkdir -p "$STAGE/test/offline/v1"
cp -R "$SOURCE/." "$STAGE/test/offline/v1/"
# 每应用独立图标：放在 v1/ 之外，不进入离线包摘要（保持网关签名有效）
mkdir -p "$STAGE/test/offline/assets"
cp "$ROOT/test_resources/app-icons/offline-demo.png" "$STAGE/test/offline/assets/app-icon.png"

python3 - "$STAGE" "$PUBLIC_ROOT" "$APP_ID" "$VERSION" <<'PY'
import hashlib
import json
import mimetypes
import pathlib
import sys

stage = pathlib.Path(sys.argv[1])
public_root = sys.argv[2].rstrip("/")
app_id = sys.argv[3]
version = sys.argv[4]
package_root = stage / "test" / "offline" / "v1"

mime_overrides = {".js": "text/javascript", ".svg": "image/svg+xml"}
files = []
for path in sorted(package_root.rglob("*")):
    if not path.is_file():
        continue
    relative = path.relative_to(package_root).as_posix()
    data = path.read_bytes()
    files.append({
        "path": relative,
        "url": f"{public_root}/v1/{relative}",
        "sha256": hashlib.sha256(data).hexdigest(),
        "size": len(data),
        "mimeType": mime_overrides.get(path.suffix, mimetypes.guess_type(path.name)[0] or "application/octet-stream"),
    })

package = {
    "schemaVersion": "1",
    "appId": app_id,
    "version": version,
    "entrypoint": "index.html",
    "files": files,
}
package_bytes = json.dumps(package, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()
package_path = stage / "test" / "offline" / "package.json"
package_path.write_bytes(package_bytes)
package_digest = hashlib.sha256(package_bytes).hexdigest()

web_manifest = {
    "id": f"{public_root}/",
    "name": "Drel Offline Demo",
    "short_name": "Offline Demo",
    "start_url": f"{public_root}/v1/index.html",
    "scope": f"{public_root}/",
    "display": "standalone",
    "theme_color": "#5b5cf0",
    "background_color": "#f7f7fb",
    "icons": [{
        "src": "https://drel.app/test/offline/assets/app-icon.png",
        "sizes": "512x512",
        "type": "image/png",
        "purpose": "any"
    }],
    "drel_offline": {
        "version": version,
        "resource_manifest": f"{public_root}/package.json",
        "resource_manifest_sha256": package_digest,
    },
}
web_bytes = json.dumps(web_manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()
web_path = stage / "test" / "offline" / "manifest.webmanifest"
web_path.write_bytes(web_bytes)
web_digest = hashlib.sha256(web_bytes).hexdigest()

parent = {
    "schemaVersion": "1",
    "appId": app_id,
    "name": "Drel Offline Demo",
    "startURL": f"{public_root}/v1/index.html",
    "allowedOrigins": ["https://drel.app"],
    "capabilities": [],
    "routes": ["/test/offline/v1/index.html"],
    "cache": {
        "strategy": "manifest",
        "version": version,
        "persistent": True,
        "resourceManifestURL": f"{public_root}/package.json",
        "resourceManifestSHA256": package_digest,
        "restoresLastState": True,
    },
    "webManifest": {"url": f"{public_root}/manifest.webmanifest", "sha256": web_digest},
    "drel_offline": {
        "version": version,
        "resource_manifest": f"{public_root}/package.json",
        "resource_manifest_sha256": package_digest,
    },
}
(stage / "test" / "offline" / "gateway-manifest.json").write_text(
    json.dumps(parent, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
)
(stage / "test" / "offline" / "build-metadata.json").write_text(
    json.dumps({"packageSHA256": package_digest, "webManifestSHA256": web_digest, "files": len(files)}, indent=2) + "\n"
)
print(f"package_sha256={package_digest}")
print(f"web_manifest_sha256={web_digest}")
print(f"files={len(files)}")
PY

(cd "$STAGE/test/offline" && zip -q -X -r drel-offline-demo-v1.zip v1 package.json manifest.webmanifest)
echo "stage=$STAGE"
