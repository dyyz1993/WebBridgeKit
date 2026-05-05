#!/bin/bash

# 白屏问题诊断脚本
# 用于排查测试用例23白屏问题

echo "========================================="
echo "测试用例23白屏问题诊断工具"
echo "========================================="
echo ""

# 1. 检查文件是否存在
echo "【步骤1】检查manifest_demo.html文件是否存在..."
FILE_PATH="DemoApp/Resources/manifest_demo.html"
if [ -f "$FILE_PATH" ]; then
    echo "✅ 文件存在: $FILE_PATH"
    echo "   文件大小: $(wc -c < "$FILE_PATH") bytes"
    echo "   行数: $(wc -l < "$FILE_PATH") lines"
else
    echo "❌ 文件不存在: $FILE_PATH"
    echo "   这是导致白屏的根本原因！"
    exit 1
fi
echo ""

# 2. 检查文件内容是否完整
echo "【步骤2】检查文件内容是否完整..."
if grep -q "<!DOCTYPE html>" "$FILE_PATH"; then
    echo "✅ HTML文档类型声明存在"
else
    echo "❌ HTML文档类型声明缺失"
fi

if grep -q "</html>" "$FILE_PATH"; then
    echo "✅ HTML闭合标签存在"
else
    echo "❌ HTML闭合标签缺失"
fi
echo ""

# 3. 检查项目配置
echo "【步骤3】检查Xcode项目配置..."
if grep -q "manifest_demo.html" WebBridgeKit.xcodeproj/project.pbxproj; then
    echo "✅ 文件已添加到Xcode项目"
    echo "   引用位置:"
    grep -n "manifest_demo.html" WebBridgeKit.xcodeproj/project.pbxproj | head -3
else
    echo "❌ 文件未添加到Xcode项目"
    echo "   需要在Xcode中手动添加该文件到项目资源"
fi
echo ""

# 4. 检查Bundle资源
echo "【步骤4】检查Bundle资源加载..."
echo "在Swift代码中检查Bundle.main.url返回值:"
echo "   let url = Bundle.main.url(forResource: \"manifest_demo\", withExtension: \"html\")"
echo "   如果返回nil，说明资源未正确打包到Bundle中"
echo ""

# 5. 检查WebView配置
echo "【步骤5】检查WebView相关配置..."
if [ -f "Sources/Core/WebBrowserManager.swift" ]; then
    echo "✅ WebBrowserManager文件存在"
else
    echo "❌ WebBrowserManager文件缺失"
fi
echo ""

# 6. 提供解决方案
echo "========================================="
echo "【解决方案】"
echo "========================================="
echo ""
echo "如果文件存在但仍然白屏，请按以下步骤操作："
echo ""
echo "1. 清理并重新编译项目："
echo "   xcodebuild clean -workspace WebBridgeKit.xcworkspace -scheme DemoApp"
echo "   xcodebuild -workspace WebBridgeKit.xcworkspace -scheme DemoApp -configuration Debug"
echo ""
echo "2. 检查文件是否正确添加到Target："
echo "   - 在Xcode中选择manifest_demo.html文件"
echo "   - 在右侧面板中勾选DemoApp target"
echo ""
echo "3. 添加调试日志："
echo "   在ManifestTestCasesViewModel.swift的executeTest方法中添加："
echo "   print(\"📍 Loading URL: \\(pageURL.absoluteString)\")"
echo "   print(\"📍 isFileURL: \\(testCase.manifestURL.isFileURL)\")"
echo ""
echo "4. 检查控制台输出："
echo "   - 运行应用并点击测试用例23"
echo "   - 查看Xcode控制台是否有错误信息"
echo "   - 检查URL是否正确指向manifest_demo.html"
echo ""
echo "5. 检查WebView加载状态："
echo "   - 在WebViewController中添加WKNavigationDelegate方法"
echo "   - 打印加载失败或成功的回调信息"
echo ""
echo "6. 检查文件权限："
echo "   ls -la DemoApp/Resources/manifest_demo.html"
echo ""
echo "诊断完成！"
