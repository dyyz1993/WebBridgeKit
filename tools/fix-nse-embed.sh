#!/bin/bash
# xcodegen 2.44.1 puts app extensions in Frameworks (dstSubfolderSpec=10)
# instead of PlugIns (13). This script patches the pbxproj after generation.
PBXPROJ="WebBridgeKit.xcodeproj/project.pbxproj"
if [ ! -f "$PBXPROJ" ]; then
  echo "pbxproj not found"; exit 1
fi

# Find the copy files phase that contains NotificationServiceExtension.appex
# and change its dstSubfolderSpec from 10 to 13
python3 - <<'PYEOF'
import re
with open("WebBridgeKit.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# Find all PBXCopyFilesBuildPhase blocks
pattern = r'(\w+ /\* Embed in .*? \*/ = \{[^}]*?isa = PBXCopyFilesBuildPhase;[^}]*?dstSubfolderSpec = 10;[^}]*?files = \([^)]*?NotificationServiceExtension[^)]*?\);[^}]*?\};)'
matches = list(re.finditer(pattern, content, re.DOTALL))
if matches:
    for m in matches:
        fixed = m.group(0).replace('dstSubfolderSpec = 10;', 'dstSubfolderSpec = 13;')
        content = content.replace(m.group(0), fixed)
    print(f"Fixed {len(matches)} copy phase(s): Frameworks(10) -> PlugIns(13)")
else:
    # Try broader: find any copy phase containing NSE and fix dstSubfolderSpec
    pattern2 = r'(\w+ /\* [^"]* \*/ = \{[^}]*?isa = PBXCopyFilesBuildPhase;[^}]*?dstSubfolderSpec = 10;[^}]*?files = \([^)]*?NotificationServiceExtension[^)]*?\))'
    matches2 = list(re.finditer(pattern2, content, re.DOTALL))
    if matches2:
        for m in matches2:
            fixed = m.group(0).replace('dstSubfolderSpec = 10;', 'dstSubfolderSpec = 13;')
            content = content.replace(m.group(0), fixed)
        print(f"Fixed {len(matches2)} copy phase(s) via pattern2")
    else:
        # Fallback: find ALL copy phases at spec 10 that have NSE in files
        blocks = re.split(r'(?=\w+ /\* .*\*/ = \{)', content)
        for i, block in enumerate(blocks):
            if 'NotificationServiceExtension' in block and 'dstSubfolderSpec = 10' in block and 'PBXCopyFilesBuildPhase' in block:
                blocks[i] = block.replace('dstSubfolderSpec = 10;', 'dstSubfolderSpec = 13;')
                print(f"Fixed block {i}")
        content = ''.join(blocks)

with open("WebBridgeKit.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)
PYEOF
