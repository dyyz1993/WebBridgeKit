#!/bin/bash

# 快速修复白屏问题脚本
# 自动添加调试日志到ManifestTestCasesViewModel.swift

echo "========================================="
echo "测试用例23白屏问题快速修复工具"
echo "========================================="
echo ""

VIEWMODEL_FILE="DemoApp/Sources/ViewModels/ManifestTestCasesViewModel.swift"

if [ ! -f "$VIEWMODEL_FILE" ]; then
    echo "❌ 找不到文件: $VIEWMODEL_FILE"
    exit 1
fi

echo "📝 备份原文件..."
cp "$VIEWMODEL_FILE" "${VIEWMODEL_FILE}.backup"
echo "✅ 备份完成: ${VIEWMODEL_FILE}.backup"
echo ""

echo "📝 添加调试日志..."

# 在第463行之后添加调试日志
sed -i '' '463 a\
\
            // ========== 白屏问题调试日志 ==========\
            print("🔍 [DEBUG] 测试用例: \\(testCase.name)")\
            print("🔍 [DEBUG] manifestURL: \\(testCase.manifestURL.absoluteString)")\
            print("🔍 [DEBUG] isFileURL: \\(testCase.manifestURL.isFileURL)")\
\
            // 验证文件是否存在\
            if testCase.manifestURL.isFileURL {\
                let fileManager = FileManager.default\
                if fileManager.fileExists(atPath: testCase.manifestURL.path) {\
                    print("✅ [DEBUG] 文件存在: \\(testCase.manifestURL.path)")\
                } else {\
                    print("❌ [DEBUG] 文件不存在: \\(testCase.manifestURL.path)")\
                    print("❌ [DEBUG] 这可能是白屏的原因！")\
                }\
            }\
            // ========== 调试日志结束 ==========
' "$VIEWMODEL_FILE"

echo "✅ 调试日志已添加"
echo ""

echo "📝 添加Bundle资源验证..."

# 在第238行附近添加验证
sed -i '' '238 i\
\
        // 验证Bundle资源是否正确加载\
        let manifestDemoURL = Bundle.main.url(forResource: "manifest_demo", withExtension: "html")\
        if manifestDemoURL == nil {\
            print("❌ [ERROR] Bundle.main.url返回nil，文件未正确打包到Bundle中")\
            print("❌ [ERROR] 请检查:")\
            print("   1. 文件是否添加到DemoApp target")\
            print("   2. Build Phases -> Copy Bundle Resources中是否包含该文件")\
            print("   3. 是否需要Clean Build Folder")\
        } else {\
            print("✅ [SUCCESS] Bundle资源加载成功: \\(manifestDemoURL!.absoluteString)")\
        }\
' "$VIEWMODEL_FILE"

echo "✅ Bundle资源验证已添加"
echo ""

echo "========================================="
echo "修复完成！"
echo "========================================="
echo ""
echo "下一步操作："
echo "1. 在Xcode中编译并运行项目"
echo "2. 点击测试用例23"
echo "3. 查看Xcode控制台输出"
echo "4. 根据日志信息定位问题"
echo ""
echo "如果需要恢复原文件，运行："
echo "mv ${VIEWMODEL_FILE}.backup ${VIEWMODEL_FILE}"
echo ""
