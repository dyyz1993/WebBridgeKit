#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
server_dir="$repo_root/Server"

test -f "$server_dir/docker-compose.self-hosted.yml"
test -f "$server_dir/docker-compose.self-hosted-nginx.yml"
test -f "$server_dir/docker-compose.self-hosted-native.yml"
test -f "$server_dir/native/Dockerfile"
test -f "$server_dir/native/data/.keep"
test -x "$repo_root/tools/verify-drel-selfhosted-native-docker.sh"
test -f "$server_dir/Caddyfile"
test -f "$server_dir/nginx/drel-self-hosted.conf.template"
test -x "$server_dir/examples/drel-encrypt-and-push.mjs"
grep -q 'caddy:2.8-alpine' "$server_dir/docker-compose.self-hosted.yml"
grep -q '"443:443"' "$server_dir/docker-compose.self-hosted.yml"
grep -q 'reverse_proxy server:8080' "$server_dir/Caddyfile"
grep -q 'condition: service_healthy' "$server_dir/docker-compose.self-hosted.yml"
grep -q 'curl -fsS http://127.0.0.1:8080/health' "$server_dir/docker-compose.self-hosted.yml"
! sed -n '/  caddy:/,/^volumes:/p' "$server_dir/docker-compose.self-hosted.yml" | grep -q 'env_file:'
grep -q '127.0.0.1:8080:8080' "$server_dir/docker-compose.self-hosted-nginx.yml"
grep -q 'proxy_pass http://127.0.0.1:8080' "$server_dir/nginx/drel-self-hosted.conf.template"
grep -q '^FROM scratch$' "$server_dir/native/Dockerfile"
grep -q 'dist/drel-selfhosted' "$server_dir/native/Dockerfile"
grep -q 'DREL_APNS_KEY_HOST_PATH' "$server_dir/docker-compose.self-hosted-native.yml"
grep -q 'DREL_CA_CERTIFICATES_HOST_PATH' "$server_dir/docker-compose.self-hosted-native.yml"
grep -q 'no-new-privileges:true' "$server_dir/docker-compose.self-hosted-native.yml"
grep -q 'cap_drop:' "$server_dir/docker-compose.self-hosted-native.yml"
grep -q 'openssl ecparam -name prime256v1' "$repo_root/tools/verify-drel-selfhosted-native-docker.sh"
grep -q 'DREL_APNS_KEY_HOST_PATH="$smoke_dir/apns-smoke.p8"' "$repo_root/tools/verify-drel-selfhosted-native-docker.sh"
! grep -q '/etc/drel-selfhosted/drel-selfhosted.env' "$repo_root/tools/verify-drel-selfhosted-native-docker.sh"
bash -n "$repo_root/tools/create-drel-selfhost-pairing.sh"
echo "PASS: Self-hosted deployment files include Caddy HTTPS, readiness checks, secret isolation, and pairing tooling"

if [[ "${DREL_SELFHOSTED_DOCKER_STATIC_ONLY:-}" == "1" ]]; then
  echo "SKIP: Docker runtime smoke intentionally disabled (static deployment validation only)."
  exit 0
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon is unavailable; run this on the self-host deployment host."
  exit 77
fi

# Compose parses the actual deployment source with a disposable non-secret
# example environment. Do not create Server/.env while validating locally.
compose_sandbox="$(mktemp -d "${TMPDIR:-/tmp}/drel-compose-config.XXXXXX")"
cleanup_compose_sandbox() { rm -rf "$compose_sandbox"; }
trap cleanup_compose_sandbox EXIT
cp -R "$server_dir" "$compose_sandbox/Server"
cp "$compose_sandbox/Server/.env.example" "$compose_sandbox/Server/.env"
docker compose \
  --project-directory "$compose_sandbox/Server" \
  --env-file "$compose_sandbox/Server/.env" \
  -f "$compose_sandbox/Server/docker-compose.self-hosted.yml" \
  config -q
echo "PASS: Self-hosted Compose configuration resolves without writing deployment credentials"

image="drel-selfhosted-smoke:local"
container="drel-selfhosted-smoke-$$"

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap 'cleanup; cleanup_compose_sandbox' EXIT

docker build -t "$image" "$server_dir" >/dev/null
docker run -d --name "$container" -p 127.0.0.1::8080 \
  -e SERVER_PORT=8080 \
  -e DATA_DIR=/app/data \
  -e DREL_SELF_HOSTED_NAME='Drel smoke test' \
  -e DREL_SELF_HOSTED_PUBLIC_BASE_URL='http://127.0.0.1:8080' \
  "$image" >/dev/null

port="$(docker port "$container" 8080/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')"
base="http://127.0.0.1:$port"

for _ in $(seq 1 30); do
  if curl --fail --silent --show-error "$base/ping" | grep -qx pong; then break; fi
  sleep 1
done
curl --fail --silent "$base/ping" | grep -qx pong

descriptor="$(curl --fail --silent "$base/.well-known/drel-push.json")"
printf '%s' "$descriptor" | grep -q 'drel.self-hosted-push.v1'

pairing="$(curl --fail --silent -X POST "$base/self-hosted/pairings")"
token="$(printf '%s' "$pairing" | sed -n 's/.*"pairingToken":"\([^"]*\)".*/\1/p')"
test -n "$token"

registration="{\"deviceToken\":\"smoke-token\",\"deviceKey\":\"smoke-key\",\"encryptionPublicKey\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\",\"pairingToken\":\"$token\",\"platform\":\"ios\"}"
curl --fail --silent -X POST "$base/self-hosted/register" \
  -H 'Content-Type: application/json' -d "$registration" | grep -q 'smoke-key'

recipient="$(curl --fail --silent "$base/self-hosted/recipients/smoke-key")"
printf '%s' "$recipient" | grep -q 'drel.self-hosted-recipient.v1'
printf '%s' "$recipient" | grep -q 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
! printf '%s' "$recipient" | grep -q 'smoke-token'

replay_status="$(curl --silent --output /dev/null --write-out '%{http_code}' -X POST "$base/self-hosted/register" \
  -H 'Content-Type: application/json' -d "$registration")"
test "$replay_status" = 401

echo "PASS: Drel self-hosted Docker descriptor, one-time pairing, and registration"
