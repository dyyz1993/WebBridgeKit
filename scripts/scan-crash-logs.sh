#!/bin/bash
# scan-crash-logs.sh — Scan crash logs from simulator, DiagnosticReports, and app sandbox
# Usage: bash scripts/scan-crash-logs.sh [--json] [--fix]

set -euo pipefail

JSON_MODE=false
FIX_MODE=false
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --fix)  FIX_MODE=true ;;
  esac
done

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

BUNDLE_ID="com.webbridgekit.superapp"
CRASHES=()
WARNINGS=()

scan_diagnostic_reports() {
  local dir="$HOME/Library/Logs/DiagnosticReports"
  local count=0
  while IFS= read -r -d '' f; do
    local name
    name=$(basename "$f")
    if [[ "$name" == SuperApp* ]] || [[ "$name" == webbridgekit* ]] || [[ "$name" == com.webbridgekit* ]]; then
      CRASHES+=("DIAG:$f")
      count=$((count + 1))
    fi
  done < <(find "$dir" -name "*.ips" -print0 2>/dev/null)
  echo "$count"
}

scan_simulator_crash_logs() {
  local sim_data_dir
  sim_data_dir=$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null || true)
  if [[ -z "$sim_data_dir" || ! -d "$sim_data_dir" ]]; then
    echo "0"
    return
  fi
  local crash_dir="$sim_data_dir/Documents/crash_logs"
  if [[ ! -d "$crash_dir" ]]; then
    echo "0"
    return
  fi
  local count=0
  while IFS= read -r -d '' f; do
    CRASHES+=("APP:$f")
    count=$((count + 1))
  done < <(find "$crash_dir" -name "*.json" -print0 2>/dev/null)
  echo "$count"
}

scan_simulator_system_log() {
  local log_tmp
  log_tmp=$(mktemp)
  xcrun simctl spawn booted log show --predicate 'subsystem == "com.webbridgekit" AND messageType >= error' --last 1h --style compact 2>/dev/null > "$log_tmp" || true
  local count
  count=$(grep -c "error\|crash\|SIGABRT\|SIGSEGV\|terminated\|OOM\|killed" "$log_tmp" 2>/dev/null || echo "0")
  if [[ "$count" -gt 0 ]]; then
    local top_errors
    top_errors=$(grep -i "error\|crash\|terminated\|killed" "$log_tmp" | sort | uniq -c | sort -rn | head -10)
    WARNINGS+=("SYSLOG ($count errors in last hour):\n$top_errors")
  fi
  rm -f "$log_tmp"
  echo "$count"
}

scan_memory_warnings() {
  local log_tmp
  log_tmp=$(mktemp)
  xcrun simctl spawn booted log show --predicate 'eventMessage CONTAINS "memory" OR eventMessage CONTAINS "OOM" OR eventMessage CONTAINS "jetsam"' --last 1h --style compact 2>/dev/null > "$log_tmp" || true
  local count
  count=$(grep -ci "memory\|OOM\|jetsam\|pressure" "$log_tmp" 2>/dev/null || echo "0")
  if [[ "$count" -gt 0 ]]; then
    WARNINGS+=("MEMORY ($count memory events in last hour)")
  fi
  rm -f "$log_tmp"
  echo "$count"
}

print_crash_detail() {
  local entry="$1"
  local type="${entry%%:*}"
  local path="${entry#*:}"
  if [[ "$type" == "APP" ]]; then
    local summary
    summary=$(python3 -c "
import json, sys
try:
  d = json.load(open('$path'))
  t = d.get('timestamp','?')
  n = d.get('name','?')
  r = d.get('reason','')[:80]
  m = d.get('memoryFootprintMB', 0)
  print(f'  [{t}] {n}: {r}  (mem={m:.0f}MB)')
except: print('  (parse error)')
" 2>/dev/null || echo "  (failed to parse $path)")
    echo -e "${RED}CRASH${NC} $summary"
  elif [[ "$type" == "DIAG" ]]; then
    local name
    name=$(basename "$path")
    local size
    size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "?")
    echo -e "${RED}CRASH${NC} DiagnosticReport: $name ($size)"
  fi
}

if [[ "$JSON_MODE" == true ]]; then
  diag_count=$(scan_diagnostic_reports)
  app_count=$(scan_simulator_crash_logs)
  echo "{\"diagnostic_reports\": $diag_count, \"app_crash_logs\": $app_count, \"total\": $((diag_count + app_count))}"
  exit 0
fi

echo ""
echo "=== Crash Log Scanner ==="
echo ""

diag_count=$(scan_diagnostic_reports)
app_count=$(scan_simulator_crash_logs)
syslog_count=$(scan_simulator_system_log)
mem_count=$(scan_memory_warnings)

echo "Results:"
echo "  DiagnosticReports (.ips):  $diag_count"
echo "  App Crash Logs (JSON):     $app_count"
echo "  System Log Errors (1h):    $syslog_count"
echo "  Memory Events (1h):        $mem_count"
echo ""

total_crashes=${#CRASHES[@]}
if [[ "$total_crashes" -gt 0 ]]; then
  echo -e "${RED}--- Crash Logs Found ($total_crashes) ---${NC}"
  for entry in "${CRASHES[@]}"; do
    print_crash_detail "$entry"
  done
  echo ""
fi

total_warnings=${#WARNINGS[@]}
if [[ "$total_warnings" -gt 0 ]]; then
  echo -e "${YELLOW}--- Warnings ($total_warnings) ---${NC}"
  for w in "${WARNINGS[@]}"; do
    echo -e "$w"
  done
  echo ""
fi

if [[ "$total_crashes" -eq 0 && "$total_warnings" -eq 0 ]]; then
  echo -e "${GREEN}No crashes or warnings found. App looks healthy.${NC}"
fi

if [[ "$FIX_MODE" == true && "$total_crashes" -gt 0 ]]; then
  echo ""
  read -p "Clear all crash logs? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for entry in "${CRASHES[@]}"; do
      local path="${entry#*:}"
      rm -f "$path"
      echo "  Deleted: $(basename "$path")"
    done
    echo -e "${GREEN}Cleared $total_crashes crash logs.${NC}"
  fi
fi
