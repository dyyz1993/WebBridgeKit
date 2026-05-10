#!/bin/bash
set -e
rm -rf /tmp/wbk-dd
cd /Users/xuyingzhou/Project/temporary/WebBridgeKit
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd 2>&1 | tail -10
echo "BUILD_EXIT_CODE=$?"
