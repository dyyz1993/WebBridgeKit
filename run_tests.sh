#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
WebBridgeKit smoke runner

Usage:
  ./run_tests.sh [smoke|services|build|test]

Commands:
  smoke     Start/verify services and run a simulator build (default)
  services  Start and verify backend, test HTTP, and prototype services
  build     Run scripts/verify-build.sh
  test      Start services and run SuperApp UI tests on a simulator

Environment:
  DERIVED_DATA_PATH   DerivedData path for build/test (default: /tmp/wbk-dd)
  LOG_PATH            Build log path for scripts/verify-build.sh
  TEST_DESTINATION    Optional xcodebuild test destination.
                      When unset, the first available iPhone simulator is used.
USAGE
}

run_services() {
    bash "$PROJECT_ROOT/scripts/services.sh" start
    bash "$PROJECT_ROOT/scripts/services.sh" verify
}

run_build() {
    bash "$PROJECT_ROOT/scripts/verify-build.sh"
}

run_tests() {
    local derived_data_path="${DERIVED_DATA_PATH:-/tmp/wbk-dd}"
    local destination="${TEST_DESTINATION:-}"

    if [ -z "$destination" ]; then
        local simulator_id
        simulator_id=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')
        if [ -z "$simulator_id" ]; then
            echo "No available iPhone simulator found. Set TEST_DESTINATION manually."
            exit 1
        fi
        destination="id=$simulator_id"
    fi

    xcodebuild test \
        -workspace "$PROJECT_ROOT/WebBridgeKit.xcworkspace" \
        -scheme SuperApp \
        -sdk iphonesimulator \
        -destination "$destination" \
        -derivedDataPath "$derived_data_path"
}

case "${1:-smoke}" in
    smoke)
        run_services
        run_build
        ;;
    services)
        run_services
        ;;
    build)
        run_build
        ;;
    test)
        run_services
        run_tests
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 64
        ;;
esac
