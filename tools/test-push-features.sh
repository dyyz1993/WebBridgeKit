#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# End-to-end push feature test suite — tests every NSE processor and
# push parameter against the live shanbox server + real device.
#
# Usage:
#   bash tools/test-push-features.sh <device-key>
#   bash tools/test-push-features.sh i0wWZf6U65RiiQ4H1dmVEbpWKAvYRo_MHJXh-FK4t3w
#
# Prerequisites: phone unlocked, app installed, push registered.
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

KEY="${1:?Usage: $0 <device-key>}"
SERVER="https://wbk.shanbox.19930810.xyz:8443"
PASSES=0; FAILS=0; SKIP=0

header() { echo -e "\n━━━ $1 ━━━"; }
pass()   { ((PASSES++)); echo "  ✅ $1"; }
fail()   { ((FAILS++)); echo "  ❌ $1"; }
skip()   { ((SKIP++)); echo "  ⏭️  $1"; }

urlencode() {
    python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

send_push() {
    local title="${1:-}" body="${2:-}" query="${3:-}"
    local enc_title enc_body
    enc_title=$(urlencode "$title")
    enc_body=$(urlencode "$body")
    local url
    if [ -n "$query" ]; then
        url="${SERVER}/${KEY}/${enc_title}/${enc_body}?${query}"
    else
        url="${SERVER}/${KEY}/${enc_title}/${enc_body}"
    fi
    local resp
    resp=$(curl -sk --max-time 15 "${url}" 2>&1) || true
    if echo "$resp" | grep -q '"code":200'; then return 0; else echo "  ⚠️  Server response: $resp"; return 1; fi
}

# ── 1. Plain push ──────────────────────────────────────────────────
header "1. Plain push (baseline)"
if send_push "自动测试-基础" "普通推送内容"; then
    pass "Server accepted plain push"
else
    fail "Server rejected plain push"
fi

# ── 2. Named sound (.caf) ─────────────────────────────────────────
header "2. Named sound"
for sound in alarm.caf birdsong.caf bloom.caf bell.caf; do
    name="${sound%.caf}"
    if send_push "铃声-${name}" "sound测试" "sound=${sound}"; then
        pass "sound=${sound} sent"
    else
        fail "sound=${sound} failed"
    fi
    sleep 2
done

# ── 3. Icon attachment ─────────────────────────────────────────────
header "3. Icon (NSE IconProcessor)"
ICON_URL="https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/images/logo.png"
if send_push "自动测试-图标" "横幅应显示自定义图标" "icon=${ICON_URL}"; then
    pass "icon push sent (check banner for custom icon)"
else
    fail "icon push failed"
fi

# ── 4. AutoCopy ────────────────────────────────────────────────────
header "4. AutoCopy (NSE AutoCopyProcessor)"
if send_push "自动测试-验证码" "你的验证码是 829104" "autoCopy=1&copy=829104&sound=birdsong.caf"; then
    pass "autoCopy push sent (clipboard should contain 829104)"
else
    fail "autoCopy push failed"
fi

# ── 5. Group/thread-id ────────────────────────────────────────────
header "5. Group (thread-id)"
if send_push "自动测试-分组" "同类通知应折叠" "group=auto-test&sound=alarm.caf"; then
    pass "group push sent"
else
    fail "group push failed"
fi
sleep 1
if send_push "自动测试-分组2" "第二条分组通知" "group=auto-test&sound=alarm.caf"; then
    pass "second group push sent (should stack in notification center)"
else
    fail "second group push failed"
fi

# ── 6. Level (timeSensitive) ──────────────────────────────────────
header "6. Interruption level"
if send_push "自动测试-时效性" "即使专注模式也会提示" "level=timeSensitive"; then
    pass "timeSensitive push sent"
else
    fail "timeSensitive push failed"
fi

# ── 7. Badge ───────────────────────────────────────────────────────
header "7. Badge"
if send_push "自动测试-角标" "角标应更新为1" "badge=1"; then
    pass "badge push sent"
else
    fail "badge push failed"
fi

# ── 8. URL click-through ──────────────────────────────────────────
header "8. URL (click-through)"
if send_push "自动测试-跳转" "点击应打开网页" "url=https://example.com"; then
    pass "url push sent"
else
    fail "url push failed"
fi

# ── 9. Copy (without autoCopy) ────────────────────────────────────
header "9. Copy content (manual)"
if send_push "自动测试-复制内容" "点击通知可复制文本" "copy=TEST_COPY_123"; then
    pass "copy push sent"
else
    fail "copy push failed"
fi

# ── 10. Markdown body ─────────────────────────────────────────────
header "10. Markdown"
if send_push "自动测试-MD" "%23%23%20%E6%A0%87%E9%A2%98%0A-%20%E5%88%97%E8%A1%A8%E9%A1%B91%0A-%20%E5%88%97%E8%A1%A8%E9%A1%B92" "markdown=1"; then
    pass "markdown push sent"
else
    fail "markdown push failed"
fi

# ── 11. Encrypted push ────────────────────────────────────────────
header "11. Encryption (ciphertext)"
# Generate a test key and encrypt a payload
ENCRYPTED=$(python3 - <<'PYEOF'
import os, base64, json
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# 128-bit test key (in production this comes from the app's keychain)
key = os.urandom(16)
nonce = os.urandom(12)
payload = json.dumps({
    "title": "🔐 加密推送成功",
    "body": "如果你能看到这条消息，说明 AES-GCM 解密正常工作！",
    "sound": "birdsong.caf"
}).encode('utf8')

ct = AESGCM(key).encrypt(nonce, payload, None)
combined = nonce + ct
print(base64.b64encode(combined).decode())
PYEOF
)
if [ -n "$ENCRYPTED" ]; then
    # Note: this uses a random key, so it will show "未配置解密密钥"
    # unless the user has set up the same key. The test verifies the
    # ciphertext parameter passes through the server.
    if send_push "自动测试" "加密参数透传测试" "ciphertext=${ENCRYPTED}"; then
        pass "ciphertext push sent (will show key-mismatch without matching key)"
    else
        fail "ciphertext push failed"
    fi
else
    skip "Python cryptography not available"
fi

# ── 12. Image (large picture) ──────────────────────────────────────
header "12. Image attachment (NSE ImageProcessor)"
IMAGE_URL="https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/images/logo.png"
if send_push "自动测试-图片" "横幅应显示图片附件" "image=${IMAGE_URL}"; then
    pass "image push sent"
else
    fail "image push failed"
fi

# ── 13. id (replacement) ──────────────────────────────────────────
header "13. Notification replacement (id)"
if send_push "自动测试-覆盖" "第一条" "id=replace-test"; then
    pass "first id push sent"
fi
sleep 2
if send_push "自动测试-覆盖更新" "第二条(应替换第一条)" "id=replace-test"; then
    pass "replacement push sent"
else
    fail "replacement push failed"
fi

# ── 14. call=1 ────────────────────────────────────────────────────
header "14. Call (30s ring)"
if send_push "自动测试-电话" "应该持续响铃30秒" "call=1&sound=alarm.caf"; then
    pass "call=1 push sent (requires App Group for 30s loop)"
else
    fail "call=1 push failed"
fi

# ── Summary ────────────────────────────────────────────────────────
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Push Feature Test Results"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Passed:  ${PASSES}"
echo "  ❌ Failed:  ${FAILS}"
echo "  ⏭️  Skipped: ${SKIP}"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total:      $((PASSES + FAILS + SKIP))"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAILS" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || echo "  ⚠️  ${FAILS} test(s) failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📱 Check your phone's notification center"
echo "  📋 Manual verification needed:"
echo "     - Icon: banner shows custom image?"
echo "     - AutoCopy: clipboard has 829104?"
echo "     - Group: notifications stacked?"
echo "     - Image: banner shows picture?"
echo "     - Call: continuous ringing?"
echo "     - Encrypted: shows decrypted or key-mismatch?"

exit $FAILS
