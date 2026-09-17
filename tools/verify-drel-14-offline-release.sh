#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT/build/reports"
REPORT="$REPORT_DIR/drel-14-offline-release.md"
mkdir -p "$REPORT_DIR"

python3 - "$ROOT" "$REPORT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
report = Path(sys.argv[2])
project = (root / "project.yml").read_text()
models = (root / "Sources/Models/HTMLAppRuntimeModels.swift").read_text()
onboarding = (root / "Sources/Runtime/HTMLAppGatewayOnboarding.swift").read_text()
installer = (root / "Sources/Runtime/HTMLAppOfflinePackageInstaller.swift").read_text()
launch_runtime = (root / "Sources/Runtime/HTMLAppLaunchRuntime.swift").read_text()
app_center = (root / "SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift").read_text()
browser_manager = (root / "Sources/Core/WebBrowserManager.swift").read_text()
web_view_controller = (root / "Sources/Controllers/WebViewController.swift").read_text()
hud_service = (root / "Sources/Utils/HUDService.swift").read_text()
super_app_sources = "\n".join(
    path.read_text(errors="ignore")
    for path in (root / "SuperApp" / "Sources").rglob("*.swift")
)

checks = {
    "Dedicated Drel14Release configuration exists": "Drel14Release:" in project,
    "Dedicated Drel14Store scheme archives Drel14Release": "Drel14Store:" in project and "archive:\n      config: Drel14Release" in project,
    "Drel 1.4 marketing version is isolated": 'MARKETING_VERSION: "1.4.0"' in project,
    "Signed parent binds Web App Manifest bytes": "webManifest: manifest.webManifest" in onboarding,
    "Onboarding verifies bound Web App Manifest": "validateBoundWebManifests" in onboarding and "webManifestAdapter.resolve" in onboarding,
    "Standard Web App Manifest adapter is implemented": "HTMLAppWebManifestAdapter" in installer and "digestMismatch" in installer,
    "Strong-offline declaration is namespaced": 'case drelOffline = "drel_offline"' in models,
    "Install and update are explicit user actions": "下载离线包" in app_center and "更新离线包" in app_center,
    "Delete is explicit and confirmed": "删除离线包？" in app_center and "confirmOfflinePackageRemoval" in app_center,
    "Installed version and disk size are visible": "packageSize(for:" in app_center and "强离线包已安装" in app_center,
    "Launch never implicitly installs or updates": "Launch does not implicitly install or update code" in app_center,
    "Installed file packages bypass the legacy manifest loader": (
        "params.useManifestLoader && !url.isFileURL" in browser_manager
        and "if url.isFileURL" in web_view_controller
        and "webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)" in web_view_controller
    ),
    "Offline download status replaces rather than stacks toast views": (
        "hudView?.removeFromSuperview()" in hud_service
        and "presentationGeneration" in hud_service
    ),
    "Uninstalled offline app launches its network page, not installation metadata": (
        "installedPackageURL ?? pageURL" in launch_runtime
        and "installedPackageURL ?? resourceManifestURL ?? pageURL" not in launch_runtime
    ),
    "Every host launch resolver uses the live shared registry": (
        "HTMLAppLaunchResolver()" not in super_app_sources
        and "trustRegistry: HTMLAppRuntimeCenter.shared.trustRegistry" in super_app_sources
        and "HTMLAppLaunchResolver(trustRegistry: trustRegistry)" in app_center
    ),
    "App Center shows only apps activated by trusted pushes": (
        "An app becomes visible only after a trusted" in app_center
        and "receivedAppStore.contains($0.appID)" in app_center
        and "HTMLAppPushActivationStore" in super_app_sources
        and "let gateway = gatewayRegistry.activeGateway() ?? HTMLAppGatewayDefaults.official" in app_center
        and "guard !isBootstrappingOfficialGateway," in app_center
        and "manifests.isEmpty || missingPresentationMetadata" not in app_center
    ),
}

# Inspect only the SuperApp Drel14Release settings block: it must not inherit
# the minimal 1.0 settings flag that intentionally hides My Apps.
anchor = project.find("Drel14Release:", project.find("SuperApp:"))
next_target = project.find("NotificationServiceExtension:", anchor)
drel14_block = project[anchor:next_target if next_target != -1 else len(project)]
checks["Drel 1.4 exposes app management"] = "DREL_RELEASE_MINIMAL_SETTINGS" not in drel14_block
checks["Container-only boundary remains enabled"] = (
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS: DREL_CONTAINER_ONLY" in drel14_block
    and "DREL_RELEASE_MINIMAL_SETTINGS" not in drel14_block
)
extension_anchor = project.find("NotificationServiceExtension:")
extension_end = project.find("SuperAppUITests:", extension_anchor)
extension_block = project[extension_anchor:extension_end]
checks["Notification extension version matches Drel 1.4"] = (
    "Drel14Release:" in extension_block
    and 'MARKETING_VERSION: "1.4.0"' in extension_block
)

failed = [name for name, ok in checks.items() if not ok]
lines = [
    "# Drel 1.4 Offline Release Boundary",
    "",
    f"- Checks: {len(checks)}",
    f"- Failures: {len(failed)}",
    "",
    "| Check | Result |",
    "|---|---|",
]
lines.extend(f"| {name} | {'PASS' if ok else 'FAIL'} |" for name, ok in checks.items())
report.write_text("\n".join(lines) + "\n")
print(f"checks={len(checks)} failures={len(failed)}")
print(f"report={report}")
if failed:
    print("failed=" + "; ".join(failed))
    raise SystemExit(1)
PY
