#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-https://drel.app/test/offline}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl --fail --silent --show-error --location "$BASE/manifest.webmanifest" -o "$TMP/manifest.webmanifest"
curl --fail --silent --show-error --location "$BASE/package.json" -o "$TMP/package.json"
curl --fail --silent --show-error --location "$BASE/drel-offline-demo-v1.zip" -o "$TMP/demo.zip"

python3 - "$BASE" "$TMP" <<'PY'
import hashlib
import json
import pathlib
import subprocess
import sys

base = sys.argv[1].rstrip("/")
tmp = pathlib.Path(sys.argv[2])
web_bytes = (tmp / "manifest.webmanifest").read_bytes()
web = json.loads(web_bytes)
package_bytes = (tmp / "package.json").read_bytes()
package = json.loads(package_bytes)
expected_package = web["drel_offline"]["resource_manifest_sha256"]
actual_package = hashlib.sha256(package_bytes).hexdigest()
assert expected_package == actual_package, "web manifest package digest mismatch"
assert package["appId"] == "dev.drel.offline-demo"
assert package["entrypoint"] == "index.html"
for item in package["files"]:
    resource_url = item["url"]
    if base != "https://drel.app/test/offline":
        resource_url = resource_url.replace("https://drel.app/test/offline", base, 1)
    data = subprocess.check_output(["curl", "--fail", "--silent", "--show-error", "--location", resource_url])
    assert len(data) == item["size"], f"size mismatch: {item['path']}"
    assert hashlib.sha256(data).hexdigest() == item["sha256"], f"digest mismatch: {item['path']}"
listing = subprocess.check_output(["unzip", "-Z1", str(tmp / "demo.zip")], text=True).splitlines()
assert "v1/index.html" in listing and "package.json" in listing and "manifest.webmanifest" in listing
print(f"PASS package_sha256={actual_package}")
print(f"PASS web_manifest_sha256={hashlib.sha256(web_bytes).hexdigest()}")
print(f"PASS files={len(package['files'])} zip_entries={len(listing)}")
PY
