#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

START_SERVICES=true
VERIFY_SERVICES=true
SETUP_GIT_HOOKS=true
GENERATE_PROJECT=true
INSTALL_PODS=true
INSTALL_MISSING_TOOLS=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[bootstrap]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

usage() {
    cat <<'EOF'
Usage: bash scripts/bootstrap-dev.sh [options]

Bootstraps the local WebBridgeKit development environment.

Options:
  --no-services        Skip starting local backend/prototype services
  --no-verify          Skip services health verification
  --no-hooks           Skip installing git hooks
  --no-xcodegen        Skip `xcodegen generate`
  --no-pods            Skip `pod install`
  --install-tools      Attempt to install missing tools when possible
  -h, --help           Show this help

Examples:
  bash scripts/bootstrap-dev.sh
  bash scripts/bootstrap-dev.sh --no-services
  bash scripts/bootstrap-dev.sh --install-tools --no-services
EOF
}

install_with_brew() {
    local package="$1"
    if ! command -v brew >/dev/null 2>&1; then
        fail "Homebrew is required to install $package automatically"
        return 1
    fi

    log "Installing $package with Homebrew ..."
    brew install "$package"
}

install_xcpretty() {
    log "Installing xcpretty gem ..."
    if gem install xcpretty --no-document >/dev/null 2>&1; then
        return 0
    fi

    if gem install --user-install xcpretty --no-document >/dev/null 2>&1; then
        warn "xcpretty was installed with --user-install. Add your Ruby gem bin path to PATH if needed."
        return 0
    fi

    fail "Unable to install xcpretty automatically"
    return 1
}

require_command() {
    local command_name="$1"
    local install_hint="$2"
    local installer="${3:-}"

    if command -v "$command_name" >/dev/null 2>&1; then
        ok "Found $command_name"
        return 0
    fi

    if [ "$INSTALL_MISSING_TOOLS" = true ] && [ -n "$installer" ]; then
        if eval "$installer"; then
            if command -v "$command_name" >/dev/null 2>&1; then
                ok "Installed $command_name"
                return 0
            fi
        fi
    fi

    fail "Missing required tool: $command_name"
    echo "      Install with: $install_hint"
    return 1
}

require_optional_command() {
    local command_name="$1"
    local install_hint="$2"
    local installer="${3:-}"

    if command -v "$command_name" >/dev/null 2>&1; then
        ok "Found optional tool $command_name"
        return 0
    fi

    if [ "$INSTALL_MISSING_TOOLS" = true ] && [ -n "$installer" ]; then
        if eval "$installer"; then
            if command -v "$command_name" >/dev/null 2>&1; then
                ok "Installed optional tool $command_name"
                return 0
            fi
        fi
    fi

    warn "Optional tool missing: $command_name"
    echo "       Install with: $install_hint"
    return 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --no-services)
            START_SERVICES=false
            VERIFY_SERVICES=false
            ;;
        --no-verify)
            VERIFY_SERVICES=false
            ;;
        --no-hooks)
            SETUP_GIT_HOOKS=false
            ;;
        --no-xcodegen)
            GENERATE_PROJECT=false
            ;;
        --no-pods)
            INSTALL_PODS=false
            ;;
        --install-tools)
            INSTALL_MISSING_TOOLS=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

cd "$PROJECT_ROOT"

log "Checking required development tools ..."
require_command "xcodebuild" "Install Xcode from the App Store or developer.apple.com"
require_command "python3" "Install Python 3"
require_command "xcodegen" "brew install xcodegen" "install_with_brew xcodegen"
require_command "pod" "brew install cocoapods" "install_with_brew cocoapods"
require_command "swiftlint" "brew install swiftlint" "install_with_brew swiftlint"
require_optional_command "xcpretty" "gem install xcpretty --no-document" install_xcpretty
require_optional_command "xcodebuildmcp" "npm install -g xcodebuildmcp@latest"

if [ "$GENERATE_PROJECT" = true ]; then
    log "Generating Xcode project ..."
    xcodegen generate --spec project.yml --project .
    ok "Generated WebBridgeKit.xcodeproj"
fi

if [ "$INSTALL_PODS" = true ]; then
    log "Installing CocoaPods dependencies ..."
    pod install
    ok "Installed Pods"
fi

if [ "$SETUP_GIT_HOOKS" = true ]; then
    log "Installing git hooks ..."
    bash scripts/setup-git-hooks.sh
fi

if [ "$START_SERVICES" = true ]; then
    log "Starting local services ..."
    bash scripts/services.sh start
    if [ "$VERIFY_SERVICES" = true ]; then
        log "Verifying local services ..."
        bash scripts/services.sh verify
    fi
fi

echo ""
ok "Development bootstrap complete"
echo "   Workspace: $PROJECT_ROOT/WebBridgeKit.xcworkspace"
echo "   XcodeBuildMCP config: $PROJECT_ROOT/.xcodebuildmcp/config.yaml"
if [ "$START_SERVICES" = false ]; then
    echo "   Start services later with: bash scripts/services.sh start"
fi
