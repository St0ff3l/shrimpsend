#!/usr/bin/env bash
# macOS 打包：flutter build macos --release + ditto ZIP，输出到 app/dist/<version>/。
# 用法:
#   ./scripts/package_macos.sh [--overseas] [--skip-build]
#   ./scripts/package_macos.sh --all
#
# 参数:
#   --all         一次性打出国内（cn）与出海（intl）ZIP
#   --overseas    出海包；默认国内
#   --skip-build  跳过构建（不可与 --all 同用）
#
# 产物: app/dist/<x.y.z.b>/Shrimpsend-macos-<cn|intl>-<x.y.z.b>.zip
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=package_common.sh
source "$APP_ROOT/scripts/package_common.sh"
cd "$APP_ROOT"

ALL=false
OVERSEAS=false
SKIP_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --all) ALL=true ;;
    --overseas) OVERSEAS=true ;;
    --skip-build) SKIP_BUILD=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

package_assert_not_all_with_filters "$ALL" "$OVERSEAS"
package_assert_all_no_skip_build "$ALL" "$SKIP_BUILD"

package_macos_one() {
  local overseas="$1"
  local skip_build="$2"

  local region
  region="$(package_region_slug "$overseas")"
  local version
  version="$(package_read_version "$APP_ROOT")"

  local app_bundle="$APP_ROOT/build/macos/Build/Products/Release/Shrimpsend.app"
  local dist_dir="$APP_ROOT/dist/$version"
  local zip_name="Shrimpsend-macos-$region-$version.zip"
  local zip_path="$dist_dir/$zip_name"

  echo ""
  echo "==> macOS package: region=$region"

  if [[ "$skip_build" == "false" ]]; then
    if [[ "$overseas" == "true" ]]; then
      "$APP_ROOT/scripts/build-macos.sh" --overseas
    else
      "$APP_ROOT/scripts/build-macos.sh"
    fi
  fi

  if [[ ! -d "$app_bundle" ]]; then
    echo "App bundle not found: $app_bundle" >&2
    exit 1
  fi

  mkdir -p "$dist_dir"
  [[ -f "$zip_path" ]] && rm -f "$zip_path"
  echo "ZIP -> $zip_path"
  ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$zip_path"
  echo "  -> $zip_path"
}

if [[ "$ALL" == "true" ]]; then
  echo "macOS --all: cn, intl"
  package_macos_one false false
  package_macos_one true false
  echo ""
  echo "Done. All macOS artifacts under: $APP_ROOT/dist/$(package_read_version "$APP_ROOT")/"
else
  package_macos_one "$OVERSEAS" "$SKIP_BUILD"
  echo ""
  echo "Done."
fi
