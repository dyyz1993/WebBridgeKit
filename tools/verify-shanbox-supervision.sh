#!/bin/bash
# Verify whether the public shanbox WebBridgeServer has process supervision.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/shanbox-supervision-verification.md"
SSH_HOST="${WBK_SHANBOX_SSH_HOST:-shanbox}"
REMOTE_BINARY="${WBK_SHANBOX_WEBBRIDGE_BINARY:-/root/WebBridgeKit/Server/.build/release/WebBridgeServer}"
REMOTE_PORT="${WBK_SHANBOX_WEBBRIDGE_PORT:-8080}"
SERVICE_NAME="${WBK_SHANBOX_SERVICE_NAME:-webbridgeserver.service}"
SUPERVISOR_PROGRAM="${WBK_SHANBOX_SUPERVISOR_PROGRAM:-webbridgeserver}"

mkdir -p "$REPORT_DIR"

REMOTE_OUTPUT="$(
    ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_HOST" \
        "REMOTE_BINARY='$REMOTE_BINARY' REMOTE_PORT='$REMOTE_PORT' SERVICE_NAME='$SERVICE_NAME' SUPERVISOR_PROGRAM='$SUPERVISOR_PROGRAM' bash -s" <<'REMOTE'
set -euo pipefail

value() {
    local key="$1"
    shift
    printf '%s=%s\n' "$key" "$*"
}

pid1="$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]' || true)"
binary_pattern="^${REMOTE_BINARY}$"
pid="$(pgrep -f "$binary_pattern" | head -1 || true)"

value host "$(hostname 2>/dev/null || echo unknown)"
value pid1 "${pid1:-unknown}"
value binary "$REMOTE_BINARY"
value port "$REMOTE_PORT"
value process_pid "${pid:-none}"

if [ -n "$pid" ]; then
    value process_state "$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]' || echo unknown)"
    value process_parent "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]' || echo unknown)"
    value process_started "$(ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^ *//' || echo unknown)"
else
    value process_state "missing"
    value process_parent "none"
    value process_started "none"
fi

if (ss -ltnp 2>/dev/null || netstat -ltnp 2>/dev/null || true) | grep -q ":${REMOTE_PORT}.*WebBridgeServer"; then
    value listen_port "yes"
else
    value listen_port "no"
fi

if [ "$pid1" = "systemd" ]; then
    value systemd_pid1 "yes"
else
    value systemd_pid1 "no"
fi

unit_path=""
for candidate in \
    "/etc/systemd/system/$SERVICE_NAME" \
    "/lib/systemd/system/$SERVICE_NAME" \
    "/usr/lib/systemd/system/$SERVICE_NAME"
do
    if [ -f "$candidate" ]; then
        unit_path="$candidate"
        break
    fi
done

value systemd_unit_path "${unit_path:-none}"
if [ -n "$unit_path" ]; then
    value systemd_unit_exists "yes"
    value systemd_unit_restart "$(awk -F= '/^Restart=/{print $2; found=1} END{if(!found) print "none"}' "$unit_path")"
else
    value systemd_unit_exists "no"
    value systemd_unit_restart "none"
fi

if command -v systemctl >/dev/null 2>&1; then
    value systemctl_available "yes"
    systemd_active_value="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)"
    systemd_enabled_value="$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || true)"
    value systemd_active "${systemd_active_value:-unavailable}"
    value systemd_enabled "${systemd_enabled_value:-unavailable}"
else
    value systemctl_available "no"
    value systemd_active "unavailable"
    value systemd_enabled "unavailable"
fi

if command -v pm2 >/dev/null 2>&1; then
    value pm2_available "yes"
    pm2_tmp="$(mktemp)"
    pm2 jlist >"$pm2_tmp" 2>/dev/null || true
    pm2_status="$(
        python3 - "$REMOTE_BINARY" "$pm2_tmp" <<'PY'
import json
import sys

binary, path = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as handle:
        processes = json.load(handle)
except Exception:
    print("unparseable")
    raise SystemExit

matches = []
for proc in processes:
    env = proc.get("pm2_env", {})
    name = proc.get("name", "")
    exec_path = env.get("pm_exec_path", "")
    cwd = env.get("pm_cwd", "")
    status = env.get("status", "unknown")
    if "webbridge" in name.lower() or exec_path == binary or "WebBridgeServer" in exec_path or "WebBridgeKit" in cwd:
        matches.append(f"{name}:{status}:{exec_path}")

print(";".join(matches) if matches else "not-found")
PY
    )"
    rm -f "$pm2_tmp"
    value pm2_webbridge "$pm2_status"
else
    value pm2_available "no"
    value pm2_webbridge "unavailable"
fi

if command -v supervisorctl >/dev/null 2>&1; then
    value supervisorctl_available "yes"
    supervisor_status="$(supervisorctl status "$SUPERVISOR_PROGRAM" 2>/dev/null || true)"
    if [ -z "$supervisor_status" ]; then
        supervisor_status="unavailable"
    fi
    value supervisor_program "$supervisor_status"
else
    value supervisorctl_available "no"
    value supervisor_program "unavailable"
fi
REMOTE
)"

get_value() {
    local key="$1"
    printf '%s\n' "$REMOTE_OUTPUT" | awk -F= -v key="$key" '$1 == key {print substr($0, length(key) + 2); exit}'
}

host="$(get_value host)"
pid1="$(get_value pid1)"
process_pid="$(get_value process_pid)"
listen_port="$(get_value listen_port)"
systemd_pid1="$(get_value systemd_pid1)"
systemd_unit_exists="$(get_value systemd_unit_exists)"
systemd_unit_restart="$(get_value systemd_unit_restart)"
systemd_active="$(get_value systemd_active)"
systemd_enabled="$(get_value systemd_enabled)"
pm2_webbridge="$(get_value pm2_webbridge)"
supervisor_program="$(get_value supervisor_program)"

process_result="FAIL"
if [ "$process_pid" != "none" ] && [ "$listen_port" = "yes" ]; then
    process_result="PASS"
fi

supervision_result="FAIL"
if [ "$systemd_pid1" = "yes" ] &&
   [ "$systemd_active" = "active" ] &&
   [ "$systemd_enabled" = "enabled" ] &&
   [ "$systemd_unit_restart" != "none" ]; then
    supervision_result="PASS"
elif printf '%s' "$pm2_webbridge" | grep -q ':online:'; then
    supervision_result="PASS"
elif printf '%s' "$supervisor_program" | grep -Eq "^${SUPERVISOR_PROGRAM}[[:space:]]+RUNNING"; then
    supervision_result="PASS"
fi

{
    echo "# shanbox WebBridgeServer Supervision Verification"
    echo ""
    echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- SSH host: \`$SSH_HOST\`"
    echo "- Remote host: \`${host:-unknown}\`"
    echo "- Binary: \`$REMOTE_BINARY\`"
    echo "- Port: \`$REMOTE_PORT\`"
    echo ""
    echo "| Check | Result | Evidence |"
    echo "|---|---|---|"
    echo "| Process running and listening | $process_result | pid=\`$process_pid\`, listen_port=\`$listen_port\`, parent=\`$(get_value process_parent)\`, started=\`$(get_value process_started)\` |"
    echo "| PID 1 supports systemd | $([ "$systemd_pid1" = "yes" ] && echo PASS || echo FAIL) | pid1=\`$pid1\` |"
    echo "| systemd unit file exists | $([ "$systemd_unit_exists" = "yes" ] && echo PASS || echo FAIL) | path=\`$(get_value systemd_unit_path)\`, Restart=\`$systemd_unit_restart\` |"
    echo "| systemd active/enabled | $([ "$systemd_active" = "active" ] && [ "$systemd_enabled" = "enabled" ] && echo PASS || echo FAIL) | active=\`$systemd_active\`, enabled=\`$systemd_enabled\` |"
    echo "| PM2 supervises WebBridgeServer | $(printf '%s' "$pm2_webbridge" | grep -q ':online:' && echo PASS || echo FAIL) | \`$pm2_webbridge\` |"
    echo "| supervisord supervises WebBridgeServer | $(printf '%s' "$supervisor_program" | grep -Eq "^${SUPERVISOR_PROGRAM}[[:space:]]+RUNNING" && echo PASS || echo FAIL) | \`$supervisor_program\` |"
    echo ""
    echo "Summary: process=$process_result, supervision=$supervision_result."
    echo ""
    echo "Raw remote facts:"
    echo '```'
    printf '%s\n' "$REMOTE_OUTPUT"
    echo '```'
} >"$REPORT"

echo "Report: $REPORT"
echo "Summary: process=$process_result, supervision=$supervision_result"

if [ "$process_result" != "PASS" ] || [ "$supervision_result" != "PASS" ]; then
    exit 1
fi
