#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${DREL_NATIVE_OUTPUT_DIR:-$root_dir/Server/native/dist}"
mkdir -p "$out_dir"

GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
  go build -trimpath -ldflags='-s -w' -o "$out_dir/drel-selfhosted" "$root_dir/Server/native/main.go"
chmod 0755 "$out_dir/drel-selfhosted"
shasum -a 256 "$out_dir/drel-selfhosted"
