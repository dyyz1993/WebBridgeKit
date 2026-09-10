#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${1:-$ROOT/build/drel-site-staging}"
SKILL="$ROOT/skills/drel-app-development"
LANDING_PAGE="$ROOT/docs/site/skills/drel-app-development/index.html"
VERSION="1.0.0"

case "$STAGE" in
  "$ROOT"/build/*) ;;
  *) echo "Refusing to replace a staging directory outside $ROOT/build" >&2; exit 2 ;;
esac

test -f "$SKILL/SKILL.md"
test -f "$LANDING_PAGE"
bash "$ROOT/tools/build-drel-offline-network-demo-site.sh" "$STAGE" >/dev/null

TARGET="$STAGE/skills/drel-app-development"
rm -rf "$TARGET"
mkdir -p "$TARGET"
cp "$LANDING_PAGE" "$TARGET/index.html"
cp -R "$SKILL/." "$TARGET/"

(cd "$TARGET" && zip -q -X -r "drel-app-development-$VERSION.zip" SKILL.md agents references)

echo "stage=$STAGE"
echo "skill=drel-app-development@$VERSION"
