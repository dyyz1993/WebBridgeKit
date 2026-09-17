#!/usr/bin/env bash
# Verify the dependency-free Docker packaging for Drel's portable Go relay.
# It uses a fresh, throwaway P-256 key solely to test container file mounts and
# pairing persistence. It never sends an APNs request or reads a deployer's
# provider key.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
native_dir="$repo_root/Server/native"
binary="$native_dir/dist/drel-selfhosted"

test -f "$native_dir/Dockerfile"
test -f "$repo_root/Server/docker-compose.self-hosted-native.yml"
test -f "$native_dir/data/.keep"

if [[ ! -x "$binary" ]]; then
  bash "$repo_root/tools/build-drel-selfhosted-native.sh"
fi

if [[ "${DREL_SELFHOSTED_NATIVE_DOCKER_STATIC_ONLY:-}" == "1" ]]; then
  echo "PASS: Native scratch Docker files and static Linux binary are present"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon is unavailable; run this on the self-host deployment host."
  exit 77
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "SKIP: openssl is required to create the disposable container-only P-256 key."
  exit 77
fi

for candidate in \
  "${DREL_CA_CERTIFICATES_HOST_PATH:-}" \
  /etc/ssl/certs/ca-certificates.crt \
  /etc/pki/tls/certs/ca-bundle.crt \
  /etc/ssl/cert.pem; do
  if [[ -n "$candidate" && -r "$candidate" ]]; then
    ca_bundle="$candidate"
    break
  fi
done
: "${ca_bundle:?No readable host CA bundle was found; set DREL_CA_CERTIFICATES_HOST_PATH}"

smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/drel-native-docker-smoke.XXXXXX")"
project="drel-native-docker-smoke-$$"
cleanup() {
  docker compose --project-name "$project" \
    -f "$repo_root/Server/docker-compose.self-hosted-native.yml" down -v >/dev/null 2>&1 || true
  rm -rf "$smoke_dir"
}
trap cleanup EXIT

umask 077
# Use an explicit named `prime256v1` curve. Some OpenSSL defaults encode
# parameters that the static Go x509 parser correctly rejects as an unknown
# curve, even though OpenSSL itself can read the resulting file.
openssl ecparam -name prime256v1 -genkey -noout \
  -out "$smoke_dir/apns-smoke-ec.pem" >/dev/null 2>&1
openssl pkcs8 -topk8 -nocrypt -in "$smoke_dir/apns-smoke-ec.pem" \
  -out "$smoke_dir/apns-smoke.p8" >/dev/null 2>&1
rm -f "$smoke_dir/apns-smoke-ec.pem"
# This is a newly-generated, non-provider test key which is destroyed by the
# trap below. It is deliberately readable in the container so a non-root test
# process can exercise APNs-key loading without changing any real key mode.
chmod 0644 "$smoke_dir/apns-smoke.p8"

export DREL_SELF_HOSTED_PUBLIC_BASE_URL='https://push.example.test'
export DREL_SELF_HOSTED_NAME='Drel native Docker smoke'
export APNS_KEY_ID='smoke-key-id'
export APNS_TEAM_ID='smoke-team-id'
export APNS_TOPIC='com.webbridgekit.superapp'
export APNS_ENVIRONMENT='production'
export DREL_APNS_KEY_HOST_PATH="$smoke_dir/apns-smoke.p8"
export DREL_APNS_KEY_GID="$(id -g)"
export DREL_CA_CERTIFICATES_HOST_PATH="$ca_bundle"
# Let Docker allocate an unused loopback host port, then query the actual map.
export DREL_NATIVE_HOST_PORT=0

docker compose --project-name "$project" \
  -f "$repo_root/Server/docker-compose.self-hosted-native.yml" up -d --build >/dev/null

container="$(docker compose --project-name "$project" \
  -f "$repo_root/Server/docker-compose.self-hosted-native.yml" ps -q relay)"
test -n "$container"
port="$(docker port "$container" 8080/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')"
test -n "$port"
base="http://127.0.0.1:$port"

for _ in $(seq 1 15); do
  if curl --fail --silent "$base/health" | grep -q '"apnsReady":true'; then break; fi
  sleep 1
done

health="$(curl --fail --silent "$base/health")"
printf '%s' "$health" | grep -q '"status":"ok"'
printf '%s' "$health" | grep -q '"apnsReady":true'

descriptor="$(curl --fail --silent "$base/.well-known/drel-push.json")"
printf '%s' "$descriptor" | grep -q 'drel.self-hosted-push.v1'
printf '%s' "$descriptor" | grep -q '"direct"'
printf '%s' "$descriptor" | grep -q '"encrypted"'

pairing="$(curl --fail --silent -X POST "$base/self-hosted/pairings")"
ticket="$(printf '%s' "$pairing" | sed -n 's/.*"pairingToken":"\([^"]*\)".*/\1/p')"
test -n "$ticket"

registration="$(printf '{"deviceToken":"docker-smoke-token","deviceKey":"docker-smoke-key","encryptionPublicKey":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","pairingToken":"%s","platform":"ios","appVersion":"smoke"}' "$ticket")"
curl --fail --silent -X POST "$base/self-hosted/register" \
  -H 'Content-Type: application/json' -d "$registration" | grep -q 'docker-smoke-key'
curl --fail --silent "$base/self-hosted/recipients/docker-smoke-key" \
  | grep -q 'drel.self-hosted-recipient.v1'

replay_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  -X POST "$base/self-hosted/register" -H 'Content-Type: application/json' -d "$registration")"
test "$replay_status" = 400

echo "PASS: Native scratch Docker image builds without a registry and proves APNs-key mount, health, pairing, registration, recipient discovery, and ticket replay rejection"
