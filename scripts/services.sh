#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="$PROJECT_ROOT/.services"
mkdir -p "$PID_DIR"

SWIFT_PORT=8080
HTTP_PORT=8081
PROTO_PORT=8083

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[services]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

_port_pid() {
    lsof -ti ":$1" -sTCP:LISTEN 2>/dev/null || true
}

_is_alive() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

start_backend() {
    local pid
    pid=$(_port_pid "$SWIFT_PORT")
    if [ -n "$pid" ]; then
        ok "Backend already running on :$SWIFT_PORT (PID $pid)"
        return 0
    fi

    log "Starting WebBridgeServer (Swift Hummingbird) on :$SWIFT_PORT ..."
    cd "$PROJECT_ROOT/Server"
    if [ ! -f ".build/debug/WebBridgeServer" ]; then
        log "Building WebBridgeServer ..."
        swift build 2>&1 | tail -3
    fi

    SERVER_PORT=$SWIFT_PORT \
    ADMIN_API_KEY=test-admin-key \
    DATA_DIR="$PROJECT_ROOT/.data" \
    nohup .build/debug/WebBridgeServer > "$PID_DIR/backend.log" 2>&1 &
    echo $! > "$PID_DIR/backend.pid"
    sleep 2

    pid=$(_port_pid "$SWIFT_PORT")
    if [ -n "$pid" ]; then
        ok "Backend running on :$SWIFT_PORT (PID $pid)"
    else
        fail "Backend failed to start. See $PID_DIR/backend.log"
        tail -5 "$PID_DIR/backend.log"
        return 1
    fi
}

start_http() {
    local pid
    pid=$(_port_pid "$HTTP_PORT")
    if [ -n "$pid" ]; then
        ok "Test HTTP server already running on :$HTTP_PORT (PID $pid)"
        return 0
    fi

    log "Starting test HTTP server on :$HTTP_PORT ..."
    cd "$PROJECT_ROOT"
    nohup python3 -c "
import http.server, socketserver, os
os.chdir('$PROJECT_ROOT')
class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'max-age=3600')
        super().end_headers()
socketserver.TCPServer(('', $HTTP_PORT), Handler).serve_forever()
" > "$PID_DIR/http.log" 2>&1 &
    echo $! > "$PID_DIR/http.pid"
    sleep 1

    pid=$(_port_pid "$HTTP_PORT")
    if [ -n "$pid" ]; then
        ok "Test HTTP server running on :$HTTP_PORT (PID $pid)"
    else
        fail "Test HTTP server failed to start. See $PID_DIR/http.log"
        return 1
    fi
}

start_prototype() {
    local pid
    pid=$(_port_pid "$PROTO_PORT")
    if [ -n "$pid" ]; then
        ok "Prototype server already running on :$PROTO_PORT (PID $pid)"
        return 0
    fi

    log "Starting prototype HTML server on :$PROTO_PORT ..."
    cd "$PROJECT_ROOT/docs/prototype"
    nohup python3 -c "
import http.server, socketserver, os
os.chdir('$PROJECT_ROOT/docs/prototype')
class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()
socketserver.TCPServer(('', $PROTO_PORT), Handler).serve_forever()
" > "$PID_DIR/prototype.log" 2>&1 &
    echo $! > "$PID_DIR/prototype.pid"
    sleep 1

    pid=$(_port_pid "$PROTO_PORT")
    if [ -n "$pid" ]; then
        ok "Prototype server running on :$PROTO_PORT (PID $pid)"
    else
        fail "Prototype server failed to start. See $PID_DIR/prototype.log"
        return 1
    fi
}

start_all() {
    log "Starting all services ..."
    start_backend
    start_http
    start_prototype
    echo ""
    status
}

stop_service() {
    local name="$1" port="$2" pidfile="$PID_DIR/$3.pid"
    local pid
    pid=$(_port_pid "$port")
    if [ -n "$pid" ]; then
        log "Stopping $name (PID $pid, port $port) ..."
        kill "$pid" 2>/dev/null || true
        sleep 1
        pid=$(_port_pid "$port")
        if [ -n "$pid" ]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
        ok "$name stopped"
    else
        warn "$name not running"
    fi
    rm -f "$pidfile"
}

stop_all() {
    log "Stopping all services ..."
    stop_service "Prototype" "$PROTO_PORT" "prototype"
    stop_service "Test HTTP" "$HTTP_PORT" "http"
    stop_service "Backend" "$SWIFT_PORT" "backend"
    ok "All services stopped"
}

status() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║            WebBridgeKit Services Status                   ║"
    echo "╠════════════════════════════════════════════════════════════╣"

    local all_ok=true

    # Backend
    local pid
    pid=$(_port_pid "$SWIFT_PORT")
    if [ -n "$pid" ]; then
        echo -e "║  ${GREEN}●${NC} Backend (Swift)    http://localhost:$SWIFT_PORT  PID:$pid"
        echo "║    Routes: /health /push /manifest /command"
    else
        echo -e "║  ${RED}○${NC} Backend (Swift)    STOPPED"
        all_ok=false
    fi

    # HTTP
    pid=$(_port_pid "$HTTP_PORT")
    if [ -n "$pid" ]; then
        echo -e "║  ${GREEN}●${NC} Test HTTP Server  http://localhost:$HTTP_PORT  PID:$pid"
        echo "║    Serves: project root + test_resources/"
    else
        echo -e "║  ${RED}○${NC} Test HTTP Server  STOPPED"
        all_ok=false
    fi

    # Prototype
    pid=$(_port_pid "$PROTO_PORT")
    if [ -n "$pid" ]; then
        echo -e "║  ${GREEN}●${NC} Prototype HTML    http://localhost:$PROTO_PORT  PID:$pid"
        echo "║    Files: index.html, v2-current-implementation.html"
    else
        echo -e "║  ${RED}○${NC} Prototype HTML    STOPPED"
        all_ok=false
    fi

    echo "╚════════════════════════════════════════════════════════════╝"

    if [ "$all_ok" = true ]; then
        echo ""
        ok "All 3 services running"
    fi
}

verify() {
    log "Verifying services ..."
    local errors=0

    # Backend health check
    local resp
    resp=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SWIFT_PORT/health" 2>/dev/null || echo "000")
    if [ "$resp" = "200" ] || [ "$resp" = "204" ]; then
        ok "Backend /health -> $resp"
    else
        fail "Backend /health -> $resp (expected 200/204)"
        errors=$((errors + 1))
    fi

    # HTTP server
    resp=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HTTP_PORT/" 2>/dev/null || echo "000")
    if [ "$resp" = "200" ]; then
        ok "Test HTTP / -> $resp"
    else
        fail "Test HTTP / -> $resp (expected 200)"
        errors=$((errors + 1))
    fi

    # Prototype
    resp=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PROTO_PORT/index.html" 2>/dev/null || echo "000")
    if [ "$resp" = "200" ]; then
        ok "Prototype /index.html -> $resp"
    else
        fail "Prototype /index.html -> $resp (expected 200)"
        errors=$((errors + 1))
    fi

    if [ "$errors" -eq 0 ]; then
        ok "All services verified!"
    else
        fail "$errors service(s) failed verification"
        return 1
    fi
}

case "${1:-status}" in
    start)   start_all ;;
    stop)    stop_all ;;
    restart) stop_all; sleep 2; start_all ;;
    status)  status ;;
    verify)  verify ;;
    backend) start_backend ;;
    http)    start_http ;;
    proto)   start_prototype ;;
    logs)
        svc="${2:-all}"
        case "$svc" in
            backend|all) echo "=== Backend Log ===" ; tail -20 "$PID_DIR/backend.log" 2>/dev/null || warn "No log" ;;
        esac
        case "$svc" in
            http|all)    echo "=== HTTP Log ==="    ; tail -20 "$PID_DIR/http.log" 2>/dev/null || warn "No log" ;;
        esac
        case "$svc" in
            proto|all)   echo "=== Prototype Log ===" ; tail -20 "$PID_DIR/prototype.log" 2>/dev/null || warn "No log" ;;
        esac
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|verify|backend|http|proto|logs [service]}"
        echo ""
        echo "Commands:"
        echo "  start     Start all 3 services"
        echo "  stop      Stop all services"
        echo "  restart   Restart all services"
        echo "  status    Show running status (default)"
        echo "  verify    Health-check all services with curl"
        echo "  backend   Start only Swift backend (:$SWIFT_PORT)"
        echo "  http      Start only test HTTP server (:$HTTP_PORT)"
        echo "  proto     Start only prototype HTML server (:$PROTO_PORT)"
        echo "  logs [svc] Show recent logs (backend|http|proto|all)"
        ;;
esac
