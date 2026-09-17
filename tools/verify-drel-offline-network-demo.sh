#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="$ROOT/build/drel-network-demo-verify"
REPORT="$ROOT/build/reports/drel-offline-network-demo.md"

bash "$ROOT/tools/build-drel-offline-network-demo-site.sh" "$STAGE" >/dev/null
mkdir -p "$(dirname "$REPORT")"

python3 - "$STAGE" "$REPORT" <<'PY'
import hashlib
import json
import pathlib
import zipfile
import sys

stage = pathlib.Path(sys.argv[1])
report = pathlib.Path(sys.argv[2])
base = stage / "test" / "offline-network"
package_bytes = (base / "package.json").read_bytes()
package = json.loads(package_bytes)
web = json.loads((base / "manifest.webmanifest").read_bytes())
parent = json.loads((base / "gateway-manifest.json").read_text())
assert package["appId"] == "dev.drel.offline-network-demo"
assert package["entrypoint"] == "index.html"
assert web["drel_offline"]["resource_manifest_sha256"] == hashlib.sha256(package_bytes).hexdigest()
assert parent["cache"]["resourceManifestSHA256"] == hashlib.sha256(package_bytes).hexdigest()
assert parent["webManifest"]["sha256"] == hashlib.sha256((base / "manifest.webmanifest").read_bytes()).hexdigest()
for item in package["files"]:
    data = (base / "v1" / item["path"]).read_bytes()
    assert len(data) == item["size"], item["path"]
    assert hashlib.sha256(data).hexdigest() == item["sha256"], item["path"]
script = (base / "v1" / "assets" / "app.js").read_text()
for required in ("fetch(ipURL", "fetch(weatherURL", "navigator.onLine", "localStorage", "DrelRuntime"):
    assert required in script, required
with zipfile.ZipFile(base / "drel-offline-network-demo-v1.zip") as archive:
    names = set(archive.namelist())
    assert {"v1/index.html", "v1/assets/app.js", "v1/assets/app.css", "package.json", "manifest.webmanifest"}.issubset(names)
lines = [
    "# Drel offline network demo verification",
    "",
    "- Result: PASS",
    f"- Package SHA-256: `{hashlib.sha256(package_bytes).hexdigest()}`",
    f"- Resources: {len(package['files'])}",
    "- Runtime data: online fetch; offline cached-result/failure fallback",
]
report.write_text("\n".join(lines) + "\n")
print(f"checks=12 failures=0 report={report}")
PY
