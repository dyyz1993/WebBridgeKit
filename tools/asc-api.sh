#!/usr/bin/env bash
# App Store Connect API helper for Drel (WebBridgeKit).
#
# Signs ES256 JWTs with a team API key (.p8) and wraps common read/write
# calls used by the release flow. The .p8 itself NEVER lives in this repo;
# it is read from the user's home directory (or ASC_API_KEY_PATH).
#
# Usage:
#   tools/asc-api.sh build <version>            Show build state for version N
#   tools/asc-api.sh versions                   List App Store versions
#   tools/asc-api.sh attach <build-id> <ver-id> Attach a processed build to an App Store version
#   tools/asc-api.sh get <api-path>             Raw authenticated GET (e.g. /v1/apps/6802806992)
#
# Overridable via environment:
#   ASC_KEY_ID (default: the active "管理员" team key)
#   ASC_KEY_PATH, ASC_ISSUER_ID, ASC_APP_ID

set -euo pipefail

ASC_KEY_ID="${ASC_KEY_ID:-4NXJ8HL7K9}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_4NXJ8HL7K9.p8}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-18f47979-0b65-4045-b969-00ba54177716}"
ASC_APP_ID="${ASC_APP_ID:-6802806992}"
ASC_API="https://api.appstoreconnect.apple.com"

OPENSSL="$(command -v openssl || echo /usr/bin/openssl)"
PYTHON3="$(command -v python3)"

b64url() { "$OPENSSL" base64 -A | tr '+/' '-_' | tr -d '='; }

# ES256 JWT: LibreSSL/openssl emit DER-encoded ECDSA signatures, but JWS
# requires the raw r||s form (64 bytes). Convert after signing.
asc_jwt() {
    local header payload der raw
    header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)
    payload=$(printf '{"iss":"%s","exp":%s,"aud":"appstoreconnect-v1"}' \
        "$ASC_ISSUER_ID" "$(( $(date +%s) + 1200 ))" | b64url)
    der=$(printf '%s.%s' "$header" "$payload" \
        | "$OPENSSL" dgst -sha256 -sign "$ASC_KEY_PATH" -binary | "$OPENSSL" base64 -A)
    raw=$(printf '%s' "$der" | "$PYTHON3" -c '
import base64, sys
der = base64.b64decode(sys.stdin.read().strip())
i = 2
rlen = der[i + 1]; r = der[i + 2:i + 2 + rlen]
j = i + 2 + rlen
slen = der[j + 1]; s = der[j + 2:j + 2 + slen]
print(base64.urlsafe_b64encode((r[-32:].rjust(32, b"\0") + s[-32:].rjust(32, b"\0"))).decode().rstrip("="))')
    printf '%s.%s.%s' "$header" "$payload" "$raw"
}

asc_get() { # $1 = API path
    /usr/bin/curl -sg -H "Authorization: Bearer $(asc_jwt)" "$ASC_API$1"
}

cmd="${1:-}"
case "$cmd" in
    build)
        version="${2:?usage: asc-api.sh build <version>}"
        asc_get "/v1/builds?filter%5Bapp%5D=$ASC_APP_ID&filter%5Bversion%5D=$version&fields%5Bbuilds%5D=version,processingState,uploadedDate,usesNonExemptEncryption" \
        | "$PYTHON3" -c '
import json, sys
d = json.load(sys.stdin)
rows = d.get("data", [])
for b in rows:
    a = b["attributes"]
    print("Build", a.get("version"), "| state=", a.get("processingState"),
          "| uploaded=", a.get("uploadedDate"),
          "| encryption_declared=", a.get("usesNonExemptEncryption"),
          "| id=", b["id"])
if not rows:
    print("no matching build")'
        ;;
    versions)
        asc_get "/v1/apps/$ASC_APP_ID/appStoreVersions" \
        | "$PYTHON3" -c '
import json, sys
d = json.load(sys.stdin)
for v in d.get("data", []):
    a = v["attributes"]
    print(a.get("versionString"), "[", a.get("appStoreVersionState"), "] id=", v["id"])
if not d.get("data"):
    print("(no versions)", json.dumps(d.get("errors", ""))[:200])'
        ;;
    attach)
        build_id="${2:?usage: asc-api.sh attach <build-id> <version-id>}"
        version_id="${3:?usage: asc-api.sh attach <build-id> <version-id>}"
        /usr/bin/curl -sg -X PATCH -H "Authorization: Bearer $(asc_jwt)" -H 'Content-Type: application/json' \
            -d '{"data":{"type":"appStoreVersions","id":"'"$version_id"'","relationships":{"build":{"data":{"type":"builds","id":"'"$build_id"'"}}}}}' \
            "$ASC_API/v1/appStoreVersions/$version_id" -w '\nHTTP %{http_code}\n'
        ;;
    get)
        asc_get "${2:?usage: asc-api.sh get <api-path>}"
        ;;
    *)
        sed -n '2,20p' "$0"
        exit 1
        ;;
esac
