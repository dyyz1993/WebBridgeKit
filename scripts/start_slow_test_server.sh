#!/bin/bash
##############################################################################
# Slow Test Server Startup Script
#
# This script starts the slow HTTP test server for testing WebBridgeKit
# under various network conditions.
#
# Usage:
#   ./scripts/start_slow_test_server.sh [options]
#
# Options:
#   --port PORT          Port to listen on (default: 8081)
#   --delay DELAY        Default delay in milliseconds (default: 1000)
#   --help               Show this help message
#
# Examples:
#   ./scripts/start_slow_test_server.sh
#   ./scripts/start_slow_test_server.sh --port 8082
#   ./scripts/start_slow_test_server.sh --port 8082 --delay 2000
##############################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
DEFAULT_PORT=8081
DEFAULT_DELAY=1000

# Parse arguments
PORT="$DEFAULT_PORT"
DELAY="$DEFAULT_DELAY"

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --delay)
            DELAY="$2"
            shift 2
            ;;
        --help|-h)
            echo "Slow Test Server Startup Script"
            echo ""
            echo "Usage:"
            echo "  $0 [options]"
            echo ""
            echo "Options:"
            echo "  --port PORT          Port to listen on (default: $DEFAULT_PORT)"
            echo "  --delay DELAY        Default delay in milliseconds (default: $DEFAULT_DELAY)"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --port 8082"
            echo "  $0 --port 8082 --delay 2000"
            echo ""
            echo "Server Endpoints:"
            echo "  http://localhost:$PORT/slow/test    - Slow response"
            echo "  http://localhost:$PORT/large/file   - Large file download"
            echo "  http://localhost:$PORT/normal/test  - Normal speed"
            echo "  http://localhost:$PORT/health       - Health check"
            echo ""
            echo "URL Parameters:"
            echo "  ?delay=2000           - Set delay to 2000ms"
            echo "  ?bandwidth=100kbps    - Limit bandwidth to 100kbps"
            echo "  ?delay=5000&bandwidth=50kbps - Combine both"
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Server script
SERVER_SCRIPT="$SCRIPT_DIR/slow_test_server.py"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    exit 1
fi

# Check if server script exists
if [[ ! -f "$SERVER_SCRIPT" ]]; then
    echo "Error: Server script not found: $SERVER_SCRIPT"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

echo "=============================================================================="
echo "Starting Slow HTTP Test Server"
echo "=============================================================================="
echo "Project Directory: $PROJECT_DIR"
echo "Server Script: $SERVER_SCRIPT"
echo "Port: $PORT"
echo "Default Delay: ${DELAY}ms"
echo "=============================================================================="
echo ""

# Start the server
python3 "$SERVER_SCRIPT" --port "$PORT" --default-delay "$DELAY"

# Exit with server's exit code
exit $?
