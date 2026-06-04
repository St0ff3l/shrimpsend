#!/usr/bin/env bash
# iOS 打包：flutter build ipa + 复制到 app/dist/<version>/。
# 用法:
#   ./scripts/package_ios.sh [--overseas] [--skip-build] [ipa|ios] [-- flutter 参数]
#   ./scripts/package_ios.sh --all
#
# 参数:
#   --all         一次性打出国内（cn）与出海（intl）IPA
#   --overseas    出海包；默认国内
#   --skip-build  跳过构建（不可与 --all 同用）
#
# 产物: app/dist/<x.y.z.b>/Shrimpsend-ios-<cn|intl>-<x.y.z.b>.ipa
# cn → dev.ultrasend.app.cn；intl → dev.ultrasend.app（Xcode flavor cn/intl）
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=package_common.sh
source "$APP_ROOT/scripts/package_common.sh"
cd "$APP_ROOT"

ALL=false
OVERSEAS=false
SKIP_BUILD=false
FLUTTER_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --all) ALL=true ;;
    --overseas) OVERSEAS=true ;;
    --skip-build) SKIP_BUILD=true ;;
    *) FLUTTER_ARGS+=("$arg") ;;
  esac
done

package_assert_not_all_with_filters "$ALL" "$OVERSEAS"
package_assert_all_no_skip_build "$ALL" "$SKIP_BUILD"

package_ios_one() {
  local overseas="$1"
  local skip_build="$2"

  local region
  region="$(package_region_slug "$overseas")"
  local version
  version="$(package_read_version "$APP_ROOT")"
  local expected_bundle_id
  expected_bundle_id="$(package_ios_expected_bundle_id "$overseas")"

  local ipa_out_dir="$APP_ROOT/build/ios/ipa"
  local dist_dir="$APP_ROOT/dist/$version"
  local dist_ipa="$dist_dir/Shrimpsend-ios-$region-$version.ipa"

  echo ""
  echo "==> iOS package: region=$region expected_bundle_id=$expected_bundle_id"

  if [[ "$skip_build" == "false" ]]; then
    mkdir -p "$ipa_out_dir"
    rm -f "$ipa_out_dir"/*.ipa

    if [[ "$overseas" == "true" ]]; then
      if ((${#FLUTTER_ARGS[@]})); then
        "$APP_ROOT/scripts/build-ios.sh" --overseas --xcode-clean ipa "${FLUTTER_ARGS[@]}"
      else
        "$APP_ROOT/scripts/build-ios.sh" --overseas --xcode-clean ipa
      fi
    elif ((${#FLUTTER_ARGS[@]})); then
      "$APP_ROOT/scripts/build-ios.sh" ipa "${FLUTTER_ARGS[@]}"
    else
      "$APP_ROOT/scripts/build-ios.sh" ipa
    fi
  fi

  local src=""
  if ! src="$(package_ios_find_latest_ipa "$ipa_out_dir")"; then
    echo "IPA not found under $ipa_out_dir" >&2
    exit 1
  fi
  if [[ ! -f "$src" ]]; then
    echo "IPA not found: $src" >&2
    exit 1
  fi

  local actual_bundle_id display_name
  actual_bundle_id="$(package_ios_read_ipa_plist_key "$src" CFBundleIdentifier)"
  display_name="$(package_ios_read_ipa_plist_key "$src" CFBundleDisplayName 2>/dev/null || true)"
  if [[ -z "$display_name" ]]; then
    display_name="$(package_ios_read_ipa_plist_key "$src" CFBundleName 2>/dev/null || true)"
  fi

  if [[ "$actual_bundle_id" != "$expected_bundle_id" ]]; then
    echo "Bundle ID mismatch for region=$region" >&2
    echo "  expected: $expected_bundle_id" >&2
    echo "  actual:   $actual_bundle_id" >&2
    echo "  source:   $src" >&2
    exit 1
  fi

  mkdir -p "$dist_dir"
  cp -f "$src" "$dist_ipa"
  echo "  <- $(basename "$src")"
  echo "  -> $dist_ipa"
  echo "     bundle_id=$actual_bundle_id  display_name=${display_name:-"(unknown)"}"
}

if [[ "$ALL" == "true" ]]; then
  echo "iOS --all: cn, intl"
  package_ios_one false false
  package_ios_one true false
  echo ""
  echo "Done. All iOS artifacts under: $APP_ROOT/dist/$(package_read_version "$APP_ROOT")/"
else
  package_ios_one "$OVERSEAS" "$SKIP_BUILD"
  echo ""
  echo "Done."
fi
