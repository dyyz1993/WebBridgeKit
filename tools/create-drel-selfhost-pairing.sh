#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-}"
if [[ ! "$base_url" =~ ^https://[^/]+/?$ ]]; then
  echo "Usage: $0 https://push.example.com" >&2
  echo "The public self-hosted endpoint must use HTTPS." >&2
  exit 64
fi

base_url="${base_url%/}"
response="$(curl --fail --silent --show-error --request POST "$base_url/self-hosted/pairings")"

read -r configuration_url expiry <<EOF
$(printf '%s' "$response" | python3 -c '
import json, sys
payload = json.load(sys.stdin)
print(payload["configurationURL"], payload["expiresAt"])
')
EOF

printf 'Drel pairing configuration (expires %s):\n%s\n' "$expiry" "$configuration_url"

if [[ -n "${DREL_PAIRING_QR_OUTPUT:-}" ]]; then
  if ! command -v qrencode >/dev/null 2>&1; then
    echo "DREL_PAIRING_QR_OUTPUT was set, but qrencode is not installed." >&2
    exit 69
  fi
  printf '%s' "$configuration_url" | qrencode -o "$DREL_PAIRING_QR_OUTPUT" -s 10 -m 2
  printf 'QR code written to %s. Treat it as short-lived pairing material.\n' "$DREL_PAIRING_QR_OUTPUT"
fi
