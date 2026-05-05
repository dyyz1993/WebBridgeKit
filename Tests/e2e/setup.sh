#!/bin/bash

# E2E 测试环境设置脚本
# WebBridgeKit Project

set -e

PROJECT_ROOT="/Users/xuyingzhou/Project/temporary/WebBridgeKit"
cd "$PROJECT_ROOT"

echo "🔧 WebBridgeKit E2E 测试环境设置"
echo "=================================="

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 安装 Node.js 依赖
echo -e "\n📦 安装 Node.js 依赖..."
if [ -f "package.json" ]; then
    npm install
    echo -e "${GREEN}✅ Node.js 依赖安装完成${NC}"
else
    echo "❌ 未找到 package.json"
    exit 1
fi

# 2. 安装 Playwright 浏览器
echo -e "\n🌐 安装 Playwright 浏览器..."
npx playwright install chromium
echo -e "${GREEN}✅ Playwright 浏览器安装完成${NC}"

# 3. 创建测试资源目录
echo -e "\n📁 创建测试资源目录..."
mkdir -p test_resources
mkdir -p tests/e2e
mkdir -p test-results
echo -e "${GREEN}✅ 测试目录创建完成${NC}"

# 4. 检查测试资源
echo -e "\n📋 检查测试资源..."

if [ ! -f "test_resources/manifest_test.html" ]; then
    echo -e "${YELLOW}⚠️  manifest_test.html 不存在${NC}"
fi

if [ ! -f "test_resources/manifest.json" ]; then
    echo -e "${YELLOW}⚠️  manifest.json 不存在${NC}"
fi

echo -e "${GREEN}✅ 测试资源检查完成${NC}"

# 5. 设置脚本权限
echo -e "\n🔐 设置脚本权限..."
chmod +x tests/e2e/run-manifest-test.sh
chmod +x scripts/test_server.py
echo -e "${GREEN}✅ 脚本权限设置完成${NC}"

# 6. 验证 Python 环境
echo -e "\n🐍 验证 Python 环境..."
if command -v python3 &> /dev/null; then
    python3 --version
    echo -e "${GREEN}✅ Python3 可用${NC}"
else
    echo "❌ Python3 未安装"
    exit 1
fi

# 7. 验证 Xcode 环境
echo -e "\n🍺 验证 Xcode 环境..."
if command -v xcodebuild &> /dev/null; then
    xcodebuild -version
    echo -e "${GREEN}✅ Xcode 可用${NC}"
else
    echo "❌ Xcode 未安装"
    exit 1
fi

# 8. 列出可用的模拟器
echo -e "\n📱 可用的 iOS 模拟器:"
xcrun simctl list devices available | grep "iPhone" | head -n 5

echo -e "\n✅ 环境设置完成！"
echo -e "\n运行测试:"
echo -e "  ./tests/e2e/run-manifest-test.sh"
echo -e "或:"
echo -e "  npm run test:manifest"
