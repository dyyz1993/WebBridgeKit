#!/bin/bash

# WebBridgeKit Manifest Cache Test Runner
# 用法: ./run_tests.sh [test_type]
# test_type: all | lazy | persistent | basic

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_DIR="/Users/xuyingzhou/Project/temporary/WebBridgeKit"
TEST_SERVER_DIR="$PROJECT_DIR/test-server"
SCHEME="DemoApp"
SIMULATOR_NAME="iPhone 15"
SIMULATOR_OS="iOS 17.5"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印分隔线
print_separator() {
    echo "========================================"
}

# 检查依赖
check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi

    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun not found. Please install Xcode command line tools."
        exit 1
    fi

    log_success "All dependencies found"
}

# 启动模拟器
start_simulator() {
    log_info "Booting simulator..."

    # 检查模拟器是否已存在
    if xcrun simctl list devices | grep -q "$SIMULATOR_NAME"; then
        log_info "Simulator exists, booting..."
        xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
    else
        log_warning "Simulator not found, creating..."
        log_info "Please create a simulator named '$SIMULATOR_NAME' in Xcode"
        log_info "Run: xcrun simctl create ..."
    fi

    # 等待模拟器启动
    log_info "Waiting for simulator to be ready..."
    sleep 5

    log_success "Simulator ready"
}

# 编译项目
build_project() {
    log_info "Building Demo App..."

    cd "$PROJECT_DIR"

    # 清理构建
    xcodebuild clean \
        -workspace WebBridgeKit.xcworkspace \
        -scheme "$SCHEME" \
        -configuration Debug \
        -sdk iphonesimulator \
        -quiet || true

    # 编译
    xcodebuild build \
        -workspace WebBridgeKit.xcworkspace \
        -scheme "$SCHEME" \
        -configuration Debug \
        -sdk iphonesimulator \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
        -quiet || {
        log_error "Build failed"
        exit 1
    }

    log_success "Build completed"
}

# 安装应用
install_app() {
    log_info "Installing Demo App..."

    local app_path="$PROJECT_DIR/build/Build/Products/Debug-iphonesimulator/$SCHEME.app"

    if [ ! -d "$app_path" ]; then
        log_error "App not found at: $app_path"
        exit 1
    fi

    xcrun simctl install "$SIMULATOR_NAME" "$app_path"

    log_success "App installed"
}

# 启动应用
launch_app() {
    log_info "Launching Demo App..."

    local bundle_id="com.webbridgekit.demo"

    xcrun simctl launch "$SIMULATOR_NAME" "$bundle_id"

    log_success "App launched"
}

# 启动测试服务器
start_test_server() {
    log_info "Starting test server..."

    cd "$TEST_SERVER_DIR"

    # 检查端口是否被占用
    if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
        log_warning "Port 8080 already in use, trying to use existing server..."
    else
        # 启动 Python HTTP 服务器
        python3 -m http.server 8080 > /tmp/test_server.log 2>&1 &
        SERVER_PID=$!
        echo $SERVER_PID > /tmp/test_server.pid
        log_success "Test server started on port 8080 (PID: $SERVER_PID)"
    fi

    sleep 2
}

# 停止测试服务器
stop_test_server() {
    if [ -f /tmp/test_server.pid ]; then
        local pid=$(cat /tmp/test_server.pid)
        kill $pid 2>/dev/null || true
        rm /tmp/test_server.pid
        log_info "Test server stopped (PID: $pid)"
    fi
}

# 运行基础测试
run_basic_tests() {
    print_separator
    log_info "Running Basic Tests (TC-UNI-001 to TC-UNI-004)"
    print_separator

    echo ""
    log_warning "Please manually verify the following tests in the simulator:"
    echo ""
    echo "1. TC-UNI-001: Open Browser Basic Test"
    echo "   - Tap any URL test button in MainViewController"
    echo "   - Expected: WebView loads correctly with navigation bar"
    echo ""
    echo "2. TC-UNI-002: Cache Hit Test"
    echo "   - Open a test URL twice"
    echo "   - Expected: Second load shows cache status 'INTERCEPT' or 'MANIFEST'"
    echo ""
    echo "3. TC-UNI-003: Force Refresh Test"
    echo "   - Open a URL with forceRefresh=true"
    echo "   - Expected: Cache is bypassed, new content loaded"
    echo ""
    echo "4. TC-UNI-004: Animated Parameter Test"
    echo "   - Open URLs with animated=true/false"
    echo "   - Expected: Animation behavior matches parameter"
    echo ""
}

# 运行 Manifest 测试
run_manifest_tests() {
    print_separator
    log_info "Running Manifest Cache Tests (TC-MAN-001 to TC-MAN-006)"
    print_separator

    echo ""
    log_warning "Test URLs for Manifest verification:"
    echo ""
    echo "Lazy Mode Test (TC-MAN-001):"
    echo "   URL: http://localhost:8080/lazy-test/"
    echo "   Expected: Immediate HTML load, background resource download"
    echo ""
    echo "Persistent Mode Test (TC-MAN-002):"
    echo "   URL: http://localhost:8080/persistent-test/"
    echo "   Expected: Progress dialog, then display after all downloads"
    echo ""
    echo "No Manifest Test (TC-MAN-005):"
    echo "   URL: http://localhost:8080/no-manifest-test/"
    echo "   Expected: Fallback to normal WebView load"
    echo ""
}

# 运行显示模式测试
run_display_tests() {
    print_separator
    log_info "Running Display Mode Tests (TC-DISP-001 to TC-DISP-006)"
    print_separator

    echo ""
    log_warning "Test display modes in Demo App:"
    echo ""
    echo "1. TC-DISP-001: Normal Mode"
    echo "   - Navigate to Normal mode test"
    echo "   - Expected: Navigation bar visible, TabBar hidden"
    echo ""
    echo "2. TC-DISP-002: Immersive Mode"
    echo "   - Navigate to Immersive mode test"
    echo "   - Expected: Full screen, no navigation/status bar"
    echo ""
    echo "3. TC-DISP-003: Modal Mode"
    echo "   - Open modal browser"
    echo "   - Expected: Modal presentation with background dimming"
    echo ""
}

# 显示日志监控命令
show_log_monitoring() {
    print_separator
    log_info "Log Monitoring Commands"
    print_separator

    echo ""
    echo "Monitor all Demo App logs:"
    echo "  xcrun simctl spawn '$SIMULATOR_NAME' log stream --predicate 'process == \"DemoApp\"'"
    echo ""
    echo "Filter for Manifest Cache logs:"
    echo "  xcrun simctl spawn '$SIMULATOR_NAME' log stream --predicate 'process == \"DemoApp\"' | grep -E '\[LazyLoader\]|\[ManifestCache\]|\[Browser\]'"
    echo ""
    echo "Filter for cache hit notifications:"
    echo "  xcrun simctl spawn '$SIMULATOR_NAME' log stream --predicate 'process == \"DemoApp\"' | grep 'manifest-cache'"
    echo ""
}

# 主函数
main() {
    local test_type="${1:-all}"

    print_separator
    echo "     WebBridgeKit Manifest Cache Test Runner"
    print_separator
    echo ""

    # 检查依赖
    check_dependencies

    # 编译项目
    build_project

    # 启动测试服务器
    start_test_server

    # 启动模拟器
    start_simulator

    # 安装应用
    install_app

    # 启动应用
    launch_app

    # 根据测试类型显示测试说明
    case "$test_type" in
        "basic")
            run_basic_tests
            ;;
        "manifest")
            run_manifest_tests
            ;;
        "display")
            run_display_tests
            ;;
        "all")
            run_basic_tests
            echo ""
            run_manifest_tests
            echo ""
            run_display_tests
            ;;
        *)
            log_error "Unknown test type: $test_type"
            echo "Usage: $0 [all|basic|manifest|display]"
            exit 1
            ;;
    esac

    # 显示日志监控命令
    show_log_monitoring

    print_separator
    log_success "Test environment ready!"
    log_info "Press Ctrl+C to stop the test server"
    print_separator

    # 等待用户中断
    trap "stop_test_server; exit 0" INT
    wait
}

# 运行主函数
main "$@"
