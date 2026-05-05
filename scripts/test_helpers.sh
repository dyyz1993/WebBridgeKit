#!/bin/bash

###############################################################################
# WebBridgeKit Test Helper Utilities
#
# This script provides helper functions for testing manifest cache functionality
#
# Usage: source scripts/test_helpers.sh
###############################################################################

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

###############################################################################
# Logging Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_debug() {
    if [ "$DEBUG" = "true" ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

###############################################################################
# Server Management
###############################################################################

get_server_pid() {
    local port=${1:-8080}
    lsof -ti:$port 2>/dev/null
}

is_server_running() {
    local port=${1:-8080}
    local pid=$(get_server_pid $port)
    if [ -n "$pid" ]; then
        return 0
    else
        return 1
    fi
}

wait_for_server() {
    local port=${1:-8080}
    local max_wait=${2:-30}
    local count=0

    while [ $count -lt $max_wait ]; do
        if is_server_running $port; then
            return 0
        fi
        sleep 1
        ((count++))
    done

    return 1
}

test_url() {
    local url=$1
    local expected_status=${2:-200}

    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [ "$status" = "$expected_status" ]; then
        return 0
    else
        return 1
    fi
}

###############################################################################
# Simulator Management
###############################################################################

get_simulator_udid() {
    xcrun simctl list devices available | grep "iPhone 14" | head -1 | sed 's/.*(\(.*\)).*/\1/'
}

boot_simulator() {
    local udid=$1
    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl boot "$udid" 2>/dev/null
    sleep 2

    # Open Simulator app
    open -a Simulator

    log_info "Simulator booted: $udid"
}

install_app() {
    local app_path=$1
    local udid=$2

    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl install "$udid" "$app_path"
    log_success "App installed: $app_path"
}

launch_app() {
    local bundle_id=$1
    local udid=$2

    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl launch "$udid" "$bundle_id"
    log_success "App launched: $bundle_id"
}

terminate_app() {
    local bundle_id=$1
    local udid=$2

    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl terminate "$udid" "$bundle_id"
    log_info "App terminated: $bundle_id"
}

uninstall_app() {
    local bundle_id=$1
    local udid=$2

    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl uninstall "$udid" "$bundle_id"
    log_info "App uninstalled: $bundle_id"
}

###############################################################################
# Cache Management
###############################################################################

find_cache_directory() {
    local bundle_id=$1

    # Find all app containers
    find ~/Library/Developer/CoreSimulator/Devices -type d -name "$bundle_id" 2>/dev/null
}

get_cache_size() {
    local cache_dir=$1

    if [ -d "$cache_dir" ]; then
        du -sh "$cache_dir" | cut -f1
    else
        echo "0B"
    fi

list_cache_contents() {
    local cache_dir=$1

    if [ -d "$cache_dir" ]; then
        find "$cache_dir" -type f -exec ls -lh {} \; | awk '{print $5, $9}'
    fi
}

clear_cache() {
    local cache_dir=$1

    if [ -d "$cache_dir" ]; then
        rm -rf "$cache_dir"/*
        log_success "Cache cleared: $cache_dir"
    fi
}

verify_manifest_cache() {
    local cache_dir=$1

    if [ ! -d "$cache_dir" ]; then
        log_error "Cache directory not found: $cache_dir"
        return 1
    fi

    local manifest_file="${cache_dir}/manifest.json"
    if [ ! -f "$manifest_file" ]; then
        log_warning "manifest.json not found in cache"
        return 1
    fi

    # Validate JSON
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$manifest_file" > /dev/null 2>&1; then
            log_success "manifest.json is valid"
        else
            log_error "manifest.json is invalid"
            return 1
        fi
    fi

    # Count cached resources
    local resource_count=$(find "$cache_dir" -type f -name "*.dat" | wc -l | tr -d ' ')
    log_info "Cached resources: $resource_count"

    return 0
}

###############################################################################
# Performance Measurement
###############################################################################

measure_load_time() {
    local url=$1

    local start=$(date +%s%N)
    curl -s -o /dev/null "$url"
    local end=$(date +%s%N)

    local duration=$(( (end - start) / 1000000 ))
    echo "${duration}ms"
}

measure_network_usage() {
    local url=$1

    local bytes=$(curl -s -o /dev/null -w "%{size_download}" "$url")
    echo "${bytes} bytes"
}

benchmark_page_load() {
    local url=$1
    local iterations=${2:-5}

    log_info "Benchmarking page load: $url ($iterations iterations)"

    local total_time=0
    local total_bytes=0

    for i in $(seq 1 $iterations); do
        log_debug "Iteration $i/$iterations"

        local time=$(measure_load_time "$url")
        local bytes=$(measure_network_usage "$url")

        total_time=$((total_time + $(echo $time | sed 's/ms//')))
        total_bytes=$((total_bytes + $(echo $bytes | sed 's/ bytes//')))

        log_debug "Time: $time, Bytes: $bytes"
    done

    local avg_time=$((total_time / iterations))
    local avg_bytes=$((total_bytes / iterations))

    log_success "Average load time: ${avg_time}ms"
    log_success "Average network usage: ${avg_bytes} bytes"
}

###############################################################################
# Test Reporting
###############################################################################

create_test_report() {
    local output_file=$1
    local template=${2:-test_report_template.md}

    if [ ! -f "$template" ]; then
        log_error "Template not found: $template"
        return 1
    fi

    # Create report from template with current date/time
    local date=$(date '+%Y-%m-%d')
    local time=$(date '+%H:%M:%S')
    local timestamp=$(date '+%Y%m%d_%H%M%S')

    cp "$template" "$output_file"

    # Replace placeholders
    sed -i '' "s/{{DATE}}/$date/g" "$output_file"
    sed -i '' "s/{{TIME}}/$time/g" "$output_file"
    sed -i '' "s/{{TIMESTAMP}}/$timestamp/g" "$output_file"

    log_success "Test report created: $output_file"
}

capture_screenshot() {
    local output_file=$1
    local udid=$2

    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl io "$udid" screenshot "$output_file"
    log_success "Screenshot saved: $output_file"
}

start_screen_recording() {
    local output_file=$1
    local udid=$2

    if [ -z "$udid" ]; then
        udid=$(get_simulator_udid)
    fi

    xcrun simctl io "$udid" recordVideo "$output_file" &
    local recorder_pid=$!

    echo $recorder_pid
}

stop_screen_recording() {
    local recorder_pid=$1

    if [ -n "$recorder_pid" ]; then
        kill -INT $recorder_pid
        wait $recorder_pid 2>/dev/null
        log_success "Screen recording stopped"
    fi
}

###############################################################################
# Validation Functions
###############################################################################

validate_file_exists() {
    local file=$1
    local description=${2:-"File"}

    if [ -f "$file" ]; then
        log_success "$description exists: $file"
        return 0
    else
        log_error "$description not found: $file"
        return 1
    fi
}

validate_json() {
    local file=$1
    local description=${2:-"JSON file"}

    if [ ! -f "$file" ]; then
        log_error "$description not found: $file"
        return 1
    fi

    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$file" > /dev/null 2>&1; then
            log_success "$description is valid JSON"
            return 0
        else
            log_error "$description is invalid JSON"
            return 1
        fi
    else
        log_warning "Python3 not found, skipping JSON validation"
        return 0
    fi
}

validate_endpoint() {
    local url=$1
    local description=${2:-"Endpoint"}
    local expected_status=${3:-200}

    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    if [ "$status" = "$expected_status" ]; then
        log_success "$description accessible: $url (HTTP $status)"
        return 0
    else
        log_error "$description returned HTTP $status: $url"
        return 1
    fi
}

###############################################################################
# Utility Functions
###############################################################################

print_banner() {
    local text=$1
    local width=${2:-60}

    local padding=$(( (width - ${#text}) / 2 ))
    local line=$(printf '%*s' "$width" | tr ' ' '=')

    echo ""
    echo "$line"
    printf "%*s%s\n" $padding '' "$text"
    echo "$line"
    echo ""
}

print_section() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

prompt_yes_no() {
    local prompt=$1
    local default=${2:-"n"}

    local prompt_text="$prompt"
    if [ "$default" = "y" ]; then
        prompt_text="$prompt [Y/n]: "
    else
        prompt_text="$prompt [y/N]: "
    fi

    read -p "$prompt_text" response

    if [ -z "$response" ]; then
        response=$default
    fi

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_key() {
    local prompt=${1:-"Press any key to continue..."}
    read -n 1 -s -p "$prompt"
    echo ""
}

###############################################################################
# Export Functions
###############################################################################

export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_debug
export -f log_test

export -f get_server_pid
export -f is_server_running
export -f wait_for_server
export -f test_url

export -f get_simulator_udid
export -f boot_simulator
export -f install_app
export -f launch_app
export -f terminate_app
export -f uninstall_app

export -f find_cache_directory
export -f get_cache_size
export -f list_cache_contents
export -f clear_cache
export -f verify_manifest_cache

export -f measure_load_time
export -f measure_network_usage
export -f benchmark_page_load

export -f create_test_report
export -f capture_screenshot
export -f start_screen_recording
export -f stop_screen_recording

export -f validate_file_exists
export -f validate_json
export -f validate_endpoint

export -f print_banner
export -f print_section
export -f prompt_yes_no
export -f wait_for_key
