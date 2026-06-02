#!/bin/bash
# Validate that the module availability report covers the current app modules and known gaps.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
OUTPUT="$REPORT_DIR/module-availability-report-check.md"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"

mkdir -p "$REPORT_DIR"

"$PYTHON_BIN" - "$PROJECT_ROOT" "$OUTPUT" <<'PY'
import datetime as dt
import re
import sys
from pathlib import Path

project_root = Path(sys.argv[1])
output = Path(sys.argv[2])
availability = project_root / "docs/verification/module-availability-verification.md"
settings_vm = project_root / "SuperApp/Sources/ViewModels/SettingsViewModel.swift"
tab_controller = project_root / "SuperApp/Sources/Controllers/Tab/TabBarController.swift"

rows = []
passed = 0
failed = 0


def add(name, result, expected, actual, evidence):
    rows.append(f"| {name} | {result} | {expected} | {actual} | `{evidence}` |")


def record(condition, name, expected, actual, evidence):
    global passed, failed
    if condition:
        add(name, "PASS", expected, actual, evidence)
        passed += 1
    else:
        add(name, "FAIL", expected, actual, evidence)
        failed += 1


def row_containing(marker):
    for line in doc.splitlines():
        if line.startswith("|") and marker in line:
            return line
    return ""


doc = availability.read_text(encoding="utf-8")
settings_source = settings_vm.read_text(encoding="utf-8")
tab_source = tab_controller.read_text(encoding="utf-8")

required_sections = [
    "## Summary",
    "## Automated Evidence",
    "## Module Matrix",
    "## Items Requiring Physical Manual Verification",
    "## Remaining Unavailable And Manual-Only Items",
    "## Remaining Non-Blocking Debt",
    "## Current Availability Verdict",
]
for section in required_sections:
    record(section in doc, f"Report section {section}", "section exists", "present" if section in doc else "missing", availability)

required_modules = [
    "Web Cache",
    "Push/Bark",
    "Bridge",
    "Commands",
    "Server Ops",
    "Settings",
    "Debug Center",
    "Deep Links",
    "Server Admin",
]
for module in required_modules:
    record(f"| {module} |" in doc, f"Module matrix covers {module}", "module row exists", "present" if f"| {module} |" in doc else "missing", availability)

summary_items = [
    "Services",
    "Module UI availability",
    "JSBridge real WebView Promise smoke",
    "Cache semantics",
    "JSBridge semantics",
    "Bark/Push/message semantics",
    "Physical device install and launch",
    "Real-device Push/APNs readiness",
    "shanbox Swift backend",
    "Node admin local source",
    "shanbox Node admin console",
]
for item in summary_items:
    record(item in doc, f"Summary covers {item}", "summary item exists", "present" if item in doc else "missing", availability)

manual_items = [
    "APNs permission and device token",
    "Bark end-to-end push delivery",
    "Physical iOS Settings handoff",
    "Physical-device backend reachability",
    "Background/locked notification behavior",
]
for item in manual_items:
    record(item in doc, f"Manual verification covers {item}", "manual item exists", "present" if item in doc else "missing", availability)

match = re.search(r"enum SettingsAction: String \{(?P<body>.*?)\n    \}", settings_source, re.S)
settings_actions = re.findall(r"\bcase\s+([A-Za-z0-9_]+)", match.group("body")) if match else []
record(bool(settings_actions), "SettingsAction extraction", "one or more actions", f"{len(settings_actions)} actions", settings_vm)

for action in settings_actions:
    identifier = f"settings.cell.{action}"
    record(identifier in doc, f"Settings action documented: {action}", f"`{identifier}` appears in report", "present" if identifier in doc else "missing", availability)

appearance_is_break = "case .appearance:\n            break" in tab_source
appearance_row = row_containing("settings.cell.appearance")
appearance_marked_unavailable = "Unavailable" in appearance_row
appearance_marked_available = "Available" in appearance_row and "Unavailable" not in appearance_row
record(
    not appearance_is_break or appearance_marked_unavailable,
    "Appearance destination availability truthfulness",
    "if implementation is break, report marks it unavailable",
    "break+marked" if appearance_is_break and appearance_marked_unavailable else ("implemented" if not appearance_is_break else "break+not marked"),
    tab_controller,
)
record(
    appearance_is_break or appearance_marked_available,
    "Appearance destination implemented report status",
    "if implementation is not break, report marks it available",
    "break" if appearance_is_break else ("implemented+available" if appearance_marked_available else "implemented+not available"),
    availability,
)

settings_key = '"settings.rememberLastApp"' in settings_source
legacy_key = '"EnableLastAppMemory"' in tab_source
remember_row = row_containing("settings.cell.rememberLastApp")
remember_marked_unavailable = "Unavailable" in remember_row
remember_marked_available = "Available" in remember_row and "Unavailable" not in remember_row
record(
    not (settings_key and legacy_key) or remember_marked_unavailable,
    "Remember-last-app key mismatch truthfulness",
    "if keys mismatch, report marks restore unavailable",
    "mismatch+marked" if settings_key and legacy_key and remember_marked_unavailable else ("consistent" if not (settings_key and legacy_key) else "mismatch+not marked"),
    tab_controller,
)
record(
    (settings_key and legacy_key) or remember_marked_available,
    "Remember-last-app implemented report status",
    "if keys are aligned, report marks restore available",
    "mismatch" if settings_key and legacy_key else ("aligned+available" if remember_marked_available else "aligned+not available"),
    availability,
)

known_unavailable_markers = [
    "Push Notifications provisioning profile is unavailable",
    "Bark/APNs end-to-end delivery is unavailable",
    "Physical iOS Settings handoff not proven on real device",
]
for marker in known_unavailable_markers:
    record(marker in doc, f"Known unavailable marker: {marker}", "marker exists", "present" if marker in doc else "missing", availability)

bridge_smoke_markers = [
    "testRealWebViewBridgePromiseResolves",
    "bridge-promise-smoke.html",
    "Bridge Promise OK",
    "browserManager.webView",
    "PersistentManifestLoader",
]
for marker in bridge_smoke_markers:
    record(marker in doc, f"Real WebView JSBridge evidence: {marker}", "marker exists", "present" if marker in doc else "missing", availability)

module_ui_markers = [
    "14 tests, 0 failures",
    "Test-SuperApp-2026.06.03_00-42-24-+0800.xcresult",
    "testDebugCenterGlobalDebugPanelEntryOpensPanel",
    "testDebugCenterChildToolEntriesOpenConcreteScreens",
    "testDebugCenterChildToolContentAndActionsAreUsable",
    "diagnostics.lastAction",
    "networkDebug.cell.0",
    "networkDebug.clearButton",
    "manifest_test.stats_label",
    "manifest_test.log_view",
]
for marker in module_ui_markers:
    record(marker in doc, f"Module UI suite evidence: {marker}", "marker exists", "present" if marker in doc else "missing", availability)

debug_center_markers = [
    "debugPanel.root",
    "debugPanel.handlers.tableView",
    "diagnostics.root",
    "networkDebug.tableView",
    "cacheDashboard.root",
    "manifestCacheTest.root",
]
for marker in debug_center_markers:
    record(marker in doc, f"Debug Center concrete screen evidence: {marker}", "marker exists", "present" if marker in doc else "missing", availability)

record(
    "Bridge real WebView execution not fully available/proven" not in doc,
    "Real WebView JSBridge obsolete unavailable marker removed",
    "old unavailable marker absent",
    "absent" if "Bridge real WebView execution not fully available/proven" not in doc else "present",
    availability,
)

with output.open("w", encoding="utf-8") as handle:
    handle.write("# Module Availability Report Check\n\n")
    handle.write(f"- Date: {dt.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}\n")
    handle.write(f"- Report: `{availability}`\n")
    handle.write(f"- Settings actions discovered: {', '.join(settings_actions)}\n\n")
    handle.write("| Check | Result | Expected | Actual | Evidence |\n")
    handle.write("|---|---|---|---|---|\n")
    handle.write("\n".join(rows))
    handle.write(f"\n\nSummary: {passed} passed, {failed} failed.\n")

print(f"Report: {output}")
print(f"Summary: {passed} passed, {failed} failed.")
sys.exit(1 if failed else 0)
PY
