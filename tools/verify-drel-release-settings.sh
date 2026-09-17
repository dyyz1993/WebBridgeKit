#!/usr/bin/env bash
# Guards Drel's intentionally small Store settings surface. This is separate
# from the container-only policy: restoring a settings feature must not enable
# the web-to-native Bridge.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0

check() {
    local name="$1"
    local command="$2"
    if bash -lc "$command"; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $name" >&2
        exit 1
    fi
}

check "Release settings policy is distinct from the container security policy" \
    "rg -q 'SWIFT_ACTIVE_COMPILATION_CONDITIONS: DREL_CONTAINER_ONLY DREL_RELEASE_MINIMAL_SETTINGS' project.yml"
check "Legacy identity and key-management rows are compiled out" \
    "rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/ViewModels/SettingsViewModel.swift && rg -q 'settings.apikey.manager' SuperApp/Sources/ViewModels/SettingsViewModel.swift"
check "Release settings retains only cache storage" \
    "rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Controllers/Cache/ManagementViewController.swift && rg -q 'title = \"存储管理\"' SuperApp/Sources/Controllers/Cache/ManagementViewController.swift"
check "All hidden settings routes are compile-time guarded" \
    "test \"$(rg -c '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Controllers/Tab/TabBarController.swift)\" -ge 6"
check "Alternate encryption entry points are compile-time guarded" \
    "rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift && rg -q '#if DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift"
check "Release home does not render app-centre or gateway-management controls" \
    "rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Views/PWAHome/PWAHomeView.swift && rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift"
check "Release settings permit the Drel push-channel chooser but omit generic gateway and web-tool startup" \
    "rg -q 'title: \"推送通道\"' SuperApp/Sources/ViewModels/SettingsViewModel.swift && rg -q 'DrelPushChannelConfigurationViewController()' SuperApp/Sources/Controllers/Tab/TabBarController.swift && rg -q 'SelfHostedPushConfigurationViewController()' SuperApp/Sources/Controllers/Settings/DrelPushChannelConfigurationViewController.swift && ! rg -q 'GatewayConfigurationViewController()' SuperApp/Sources/Controllers/Tab/TabBarController.swift && rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift"
check "Drel 1.4 keeps offline preferences but hides legacy encryption and diagnostics" \
    "rg -q 'Drel14Release:' project.yml && rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY' SuperApp/Sources/ViewModels/SettingsViewModel.swift && rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY' SuperApp/Sources/Controllers/Cache/ManagementViewController.swift && rg -q '#if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift"
check "Drel 1.4 has no generic gateway action in Store-facing app controls" \
    "rg -U -q '#if !DREL_CONTAINER_ONLY\\n[[:space:]]*alert.addAction\\(UIAlertAction\\(title: \"管理应用服务\"' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift && rg -U -q '#if !DREL_CONTAINER_ONLY\\n[[:space:]]*alert.addAction\\(UIAlertAction\\(title: \"管理自有服务\"' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift"
check "Release About screen lists only shipped V1 capabilities" \
    "rg -q '#if DREL_CONTAINER_ONLY' SuperApp/Sources/Views/AboutView.swift && rg -q 'about.feature.push' SuperApp/Sources/Views/AboutView.swift && rg -q 'about.feature.secure_route' SuperApp/Sources/Views/AboutView.swift"
check "Restoration manual is present" \
    "test -f docs/release/drel-settings-feature-restoration.md && rg -q 'DREL_CONTAINER_ONLY' docs/release/drel-settings-feature-restoration.md"

echo "Summary: $PASS passed, 0 failed"
