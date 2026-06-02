#!/bin/bash
# Verify the local Node admin console routes in Server/node/server.js.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/node-admin-local-verification.md"
LOG="$REPORT_DIR/node-admin-local.log"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"
NODE_BIN="${NODE_BIN:-node}"
PORT="${PORT:-}"
SERVER_PID=""

mkdir -p "$REPORT_DIR"

if [ -z "$PORT" ]; then
    PORT="$("$PYTHON_BIN" - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
fi

BASE_URL="http://127.0.0.1:$PORT"

cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

: >"$LOG"
echo "Starting local Node admin server on $BASE_URL"
PORT="$PORT" "$NODE_BIN" "$PROJECT_ROOT/Server/node/server.js" >"$LOG" 2>&1 &
SERVER_PID="$!"

"$PYTHON_BIN" - "$BASE_URL" "$REPORT" "$LOG" <<'PY'
import datetime as dt
import json
import sys
import time
import urllib.error
import urllib.request

base_url, report_path, log_path = sys.argv[1], sys.argv[2], sys.argv[3]
rows = []


def request(path):
    url = f"{base_url}{path}"
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=5) as response:
        body = response.read()
        return response.status, response.headers.get("Content-Type", ""), body


def add_row(name, result, path, expected, actual, evidence):
    rows.append(
        f"| {name} | {result} | `GET {path}` | {expected} | {actual} | {evidence} |"
    )


def pass_check(name, path, expected, actual):
    add_row(name, "PASS", path, expected, actual, f"`{report_path}`")


def fail_check(name, path, expected, actual):
    add_row(name, "FAIL", path, expected, actual, f"`{log_path}`")


deadline = time.time() + 10
last_error = None
while time.time() < deadline:
    try:
        status, _, body = request("/health")
        data = json.loads(body.decode("utf-8"))
        if status == 200 and data.get("status") == "ok":
            break
    except Exception as error:
        last_error = error
        time.sleep(0.2)
else:
    fail_check("Server boot", "/health", "HTTP 200 JSON status=ok", repr(last_error))
    with open(report_path, "w", encoding="utf-8") as handle:
        handle.write("# Local Node Admin Verification\n\n")
        handle.write(f"- Date: {dt.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}\n")
        handle.write(f"- Base URL: `{base_url}`\n")
        handle.write(f"- Server log: `{log_path}`\n\n")
        handle.write("| Check | Result | Request | Expected | Actual | Evidence |\n")
        handle.write("|---|---|---|---|---|---|\n")
        handle.write("\n".join(rows))
        handle.write("\n\nSummary: 0 passed, 1 failed.\n")
    print(f"Report: {report_path}")
    print("Summary: 0 passed, 1 failed.")
    sys.exit(1)


checks = [
    ("Health", "/health", "health"),
    ("Admin console", "/admin", "admin-html"),
    ("Admin push console", "/admin-push", "admin-html"),
    ("Admin stats API", "/admin/api/stats", "stats"),
    ("Admin devices API", "/admin/api/devices", "array"),
    ("Admin commands API", "/admin/api/commands", "array"),
    ("Admin manifests API", "/admin/api/manifests", "array"),
    ("Admin push history API", "/admin/api/push-history", "array"),
    ("WebSocket status API", "/ws/status", "ws-status"),
    ("Messages API", "/messages", "messages"),
    ("Packages API", "/packages", "array"),
]

passed = 0
failed = 0

for name, path, kind in checks:
    try:
        status, content_type, body = request(path)
        text = body.decode("utf-8", errors="replace")
        if status != 200:
            raise AssertionError(f"HTTP {status}")

        if kind == "health":
            data = json.loads(text)
            assert data.get("status") == "ok", data
            actual = "HTTP 200 JSON status=ok"
        elif kind == "admin-html":
            assert "WebBridgeKit" in text, "missing WebBridgeKit marker"
            assert content_type.startswith("text/html"), content_type
            actual = "HTTP 200 HTML contains WebBridgeKit"
        elif kind == "stats":
            data = json.loads(text)
            required = {"devices", "commands", "manifests", "wsClients", "uptime", "startTime"}
            missing = sorted(required - set(data.keys()))
            assert not missing, f"missing keys: {missing}"
            actual = "HTTP 200 JSON stats keys present"
        elif kind == "array":
            data = json.loads(text)
            assert isinstance(data, list), type(data).__name__
            actual = f"HTTP 200 JSON array length={len(data)}"
        elif kind == "ws-status":
            data = json.loads(text)
            assert isinstance(data.get("connectedClients"), int), data
            actual = f"HTTP 200 connectedClients={data['connectedClients']}"
        elif kind == "messages":
            data = json.loads(text)
            assert isinstance(data.get("items"), list), data
            assert isinstance(data.get("total"), int), data
            actual = f"HTTP 200 items={len(data['items'])}, total={data['total']}"
        else:
            raise AssertionError(f"unknown check kind: {kind}")

        pass_check(name, path, "HTTP 200 and semantic assertion", actual)
        passed += 1
        print(f"PASS {name}: {actual}")
    except (AssertionError, json.JSONDecodeError, urllib.error.URLError, TimeoutError) as error:
        fail_check(name, path, "HTTP 200 and semantic assertion", repr(error))
        failed += 1
        print(f"FAIL {name}: {error}")

with open(report_path, "w", encoding="utf-8") as handle:
    handle.write("# Local Node Admin Verification\n\n")
    handle.write(f"- Date: {dt.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}\n")
    handle.write(f"- Base URL: `{base_url}`\n")
    handle.write(f"- Server: `Server/node/server.js`\n")
    handle.write(f"- Server log: `{log_path}`\n\n")
    handle.write("| Check | Result | Request | Expected | Actual | Evidence |\n")
    handle.write("|---|---|---|---|---|---|\n")
    handle.write("\n".join(rows))
    handle.write(f"\n\nSummary: {passed} passed, {failed} failed.\n")
    handle.write("\nNotes:\n")
    handle.write("- This verifies the local Node admin source and route behavior only.\n")
    handle.write("- It does not prove the Node admin console is deployed behind the public shanbox host.\n")

print(f"Report: {report_path}")
print(f"Summary: {passed} passed, {failed} failed.")
sys.exit(1 if failed else 0)
PY
