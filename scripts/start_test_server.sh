#!/bin/bash
# 启动WebBridgeKit测试服务器

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 启动WebBridgeKit测试HTTP服务器"
echo "📁 服务目录: $PROJECT_ROOT"
echo ""

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 python3，请先安装 Python 3"
    exit 1
fi

echo "✅ Python 3 已安装"

# 检查端口8080是否被占用
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  警告: 端口 8080 已被占用"
    echo "正在尝试停止占用端口的进程..."

    # 查找并停止占用8080端口的进程
    PID=$(lsof -ti :8080)
    if [ ! -z "$PID" ]; then
        echo "停止进程 PID: $PID"
        kill -9 "$PID"
        sleep 1
    fi
fi

# 启动服务器
echo ""
echo "启动服务器..."
python3 scripts/test_server.py
