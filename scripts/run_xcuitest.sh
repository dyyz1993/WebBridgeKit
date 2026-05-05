#!/bin/bash

# XCUITest自动化测试执行脚本
# 用于执行DemoAppUITests测试

set -e

echo "=========================================="
echo "XCUITest 自动化测试执行"
echo "=========================================="
echo ""

# 检查工作目录
if [ ! -d "/Users/xuyingzhou/Project/temporary/WebBridgeKit" ]; then
    echo "❌ 错误: 项目目录不存在"
    exit 1
fi

cd /Users/xuyingzhou/Project/temporary/WebBridgeKit

# 1. 检查模拟器
echo "📱 检查iOS模拟器..."
SIMULATOR_NAME="iPhone 16 Pro"
SIMULATOR_ID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9-]{36}')

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ 错误: 找不到模拟器 $SIMULATOR_NAME"
    echo "可用的模拟器:"
    xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10
    exit 1
fi

echo "✅ 找到模拟器: $SIMULATOR_NAME (ID: $SIMULATOR_ID)"
echo ""

# 2. 启动模拟器
echo "🚀 启动模拟器..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
echo "✅ 模拟器已启动"
echo ""

# 3. 清理构建
echo "🧹 清理构建缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/WebBridgeKit-* 2>/dev/null || true
echo "✅ 清理完成"
echo ""

# 4. 构建并测试
echo "🔨 构建测试目标..."
xcodebuild build-for-testing \
    -workspace WebBridgeKit.xcworkspace \
    -scheme DemoApp \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -quiet

if [ $? -eq 0 ]; then
    echo "✅ 构建成功"
else
    echo "❌ 构建失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "开始执行测试..."
echo "=========================================="
echo ""

# 5. 执行测试
xcodebuild test-without-building \
    -workspace WebBridgeKit.xcworkspace \
    -scheme DemoApp \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -only-testing:DemoAppUITests \
    2>&1

TEST_EXIT_CODE=$?

echo ""
echo "=========================================="
echo "测试执行完成"
echo "=========================================="

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ 所有测试通过!"
else
    echo "❌ 测试失败 (退出码: $TEST_EXIT_CODE)"
    echo ""
    echo "可能的解决方案:"
    echo "1. 检查测试文件Target Membership"
    echo "2. 确认测试类继承自XCTestCase"
    echo "3. 确认测试方法以test前缀开头"
fi

exit $TEST_EXIT_CODE
