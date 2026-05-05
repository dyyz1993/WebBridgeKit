#!/bin/bash

# Manifest Cache E2E 测试运行脚本
# WebBridgeKit Project

set -e

PROJECT_ROOT="/Users/xuyingzhou/Project/temporary/WebBridgeKit"
cd "$PROJECT_ROOT"

echo "🧪 WebBridgeKit Manifest Cache E2E Test"
echo "========================================"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 步骤 1: 检查依赖
echo -e "\n📦 检查依赖..."

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js 未安装${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm 未安装${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 未安装${NC}"
    exit 1
fi

if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}❌ Xcode tools 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 所有依赖已安装${NC}"

# 步骤 2: 检查端口 8080 是否被占用
echo -e "\n🔍 检查端口 8080..."

if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口 8080 已被占用，正在清理...${NC}"
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✅ 端口 8080 已释放${NC}"
else
    echo -e "${GREEN}✅ 端口 8080 可用${NC}"
fi

# 步骤 3: 检查模拟器
echo -e "\n📱 检查模拟器..."

SIMULATOR_ID="21045190-6163-49E0-82AD-9E4CFD5E3C55"

if ! xcrun simctl list devices | grep -q "$SIMULATOR_ID"; then
    echo -e "${YELLOW}⚠️  模拟器 $SIMULATOR_ID 未找到，尝试使用默认模拟器${NC}"
    # 获取第一个可用的 iPhone 15 模拟器
    SIMULATOR_ID=$(xcrun simctl list devices available | grep "iPhone 15" | grep -oE "[0-9A-F-]{36}" | head -n 1)
fi

if [ -z "$SIMULATOR_ID" ]; then
    echo -e "${RED}❌ 未找到可用的模拟器${NC}"
    echo "请创建 iPhone 15 模拟器："
    echo "xcrun simctl create 'iPhone 15' 'iPhone 15' 'iOS17.0'"
    exit 1
fi

echo -e "${GREEN}✅ 使用模拟器: $SIMULATOR_ID${NC}"

# 检查模拟器是否启动
if ! xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -q "Booted"; then
    echo -e "${YELLOW}⚠️  模拟器未启动，正在启动...${NC}"
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
    sleep 3
    echo -e "${GREEN}✅ 模拟器已启动${NC}"
else
    echo -e "${GREEN}✅ 模拟器已运行${NC}"
fi

# 步骤 4: 安装 npm 依赖
echo -e "\n📚 安装 npm 依赖..."

if [ ! -d "node_modules" ]; then
    echo "正在安装依赖..."
    npm install
    echo -e "${GREEN}✅ 依赖安装完成${NC}"
else
    echo -e "${GREEN}✅ 依赖已存在${NC}"
fi

# 步骤 5: 构建应用
echo -e "\n🔨 构建 DemoApp..."

if [ ! -d "build/Build/Products/Debug-iphonesimulator/DemoApp.app" ]; then
    echo "正在构建应用..."
    xcodebuild -workspace WebBridgeKit.xcworkspace -scheme DemoApp -sdk iphonesimulator -configuration Debug -destination "id=$SIMULATOR_ID" build
    echo -e "${GREEN}✅ 应用构建完成${NC}"
else
    echo -e "${GREEN}✅ 应用已存在${NC}"
fi

# 步骤 6: 运行测试
echo -e "\n🚀 运行 Manifest Cache E2E 测试..."
echo "========================================"

npm run test:manifest

# 测试完成
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}✅ 所有测试通过！${NC}"
else
    echo -e "\n${RED}❌ 测试失败，退出码: $EXIT_CODE${NC}"
fi

# 步骤 7: 清理
echo -e "\n🧹 清理测试环境..."

# 关闭测试服务器
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "关闭测试服务器..."
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    echo -e "${GREEN}✅ 测试服务器已关闭${NC}"
fi

exit $EXIT_CODE
