#!/usr/bin/env bash
# Verify cn/intl flavor wiring in project.pbxproj (run from app/ios/).
set -euo pipefail

IOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBX="$IOS_ROOT/Runner.xcodeproj/project.pbxproj"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

[[ -f "$PBX" ]] || fail "missing $PBX"

grep -q 'Debug-cn' "$PBX" || fail "Debug-cn build configuration missing"
grep -q 'Release-intl' "$PBX" || fail "Release-intl build configuration missing"

grep -q 'PRODUCT_BUNDLE_IDENTIFIER = dev.ultrasend.app.cn;' "$PBX" \
  || fail "cn bundle id missing"
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = dev.ultrasend.app;' "$PBX" \
  || fail "intl bundle id missing"

grep -q 'Runner/Runner-cn.entitlements' "$PBX" \
  || fail "Runner-cn.entitlements not referenced"
grep -q 'Runner/Runner-intl.entitlements' "$PBX" \
  || fail "Runner-intl.entitlements not referenced"
grep -q 'Share Extension/Share Extension-cn.entitlements' "$PBX" \
  || fail "Share Extension-cn.entitlements not referenced"
grep -q 'Share Extension/Share Extension-intl.entitlements' "$PBX" \
  || fail "Share Extension-intl.entitlements not referenced"

grep -q 'BUNDLE_DISPLAY_NAME = "虾传";' "$PBX" \
  || fail 'cn BUNDLE_DISPLAY_NAME "虾传" missing'
grep -q 'BUNDLE_DISPLAY_NAME = "ShrimpSend";' "$PBX" \
  || fail 'intl BUNDLE_DISPLAY_NAME "ShrimpSend" missing'

grep -q 'INFOPLIST_KEY_CFBundleDisplayName = "虾传";' "$PBX" \
  || fail 'cn display name "虾传" missing or unquoted'
grep -q 'INFOPLIST_KEY_CFBundleDisplayName = "ShrimpSend";' "$PBX" \
  || fail 'intl display name "ShrimpSend" missing'

for xc in cnRelease intlRelease; do
  [[ -f "$IOS_ROOT/Flutter/${xc}.xcconfig" ]] \
    || fail "missing Flutter/${xc}.xcconfig"
done

for pod in Pods-Runner.release-cn Pods-Runner.release-intl; do
  [[ -f "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/${pod}.xcconfig" ]] \
    || fail "run pod install — missing ${pod}.xcconfig"
done

pass "pbxproj cn/intl flavor wiring"
echo ""
echo "Apple Developer (manual): see docs/ios-dual-bundle-apple-setup.md"
echo "  - Register dev.ultrasend.app.cn + Extension + group.dev.ultrasend.app.cn"
echo "  - Create App Store Connect app for dev.ultrasend.app.cn"
