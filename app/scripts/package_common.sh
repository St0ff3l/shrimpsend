#!/usr/bin/env bash
# 各 package_*.sh 共用的版本读取与参数校验（source 引入，勿直接执行）。
set -euo pipefail

package_read_version() {
  local app_root="$1"
  local pubspec="$app_root/pubspec.yaml"
  local version_line
  version_line="$(grep -E '^version:' "$pubspec" | head -1 | sed 's/^version:[[:space:]]*//')"
  if [[ -z "$version_line" ]]; then
    echo "Cannot read version from $pubspec" >&2
    return 1
  fi
  echo "$version_line" | sed 's/+/./'
}

package_region_slug() {
  if [[ "$1" == "true" ]]; then
    echo intl
  else
    echo cn
  fi
}

# Android 发行包仅保留 arm64-v8a（与 build-android.sh / Gradle release 一致）
package_android_abi_slug() {
  echo arm64-v8a
}

package_assert_not_all_with_filters() {
  local all="$1"
  local overseas="$2"
  local play="${3:-false}"
  if [[ "$all" != "true" ]]; then
    return 0
  fi
  if [[ "$overseas" == "true" || "$play" == "true" ]]; then
    echo "错误: --all 不能与 --overseas / --play 同时使用" >&2
    return 1
  fi
}

package_assert_all_no_skip_build() {
  if [[ "$1" == "true" && "$2" == "true" ]]; then
    echo "错误: --all 需要完整构建，不能与 --skip-build 同时使用" >&2
    return 1
  fi
}

package_ios_expected_bundle_id() {
  if [[ "$1" == "true" ]]; then
    echo dev.ultrasend.app
  else
    echo dev.ultrasend.app.cn
  fi
}

package_ios_read_ipa_plist_key() {
  local ipa="$1"
  local key="$2"
  local plist_path
  plist_path="$(unzip -Z1 "$ipa" 'Payload/*.app/Info.plist' 2>/dev/null | head -1)"
  if [[ -z "$plist_path" ]]; then
    echo "Cannot find Info.plist in $ipa" >&2
    return 1
  fi
  unzip -p "$ipa" "$plist_path" | plutil -extract "$key" raw -
}

package_ios_find_latest_ipa() {
  local dir="$1"
  local -a ipas=()

  if [[ ! -d "$dir" ]]; then
    return 1
  fi

  shopt -s nullglob
  ipas=("$dir"/*.ipa)
  shopt -u nullglob

  if ((${#ipas[@]} == 0)); then
    return 1
  fi

  if ((${#ipas[@]} == 1)); then
    echo "${ipas[0]}"
    return 0
  fi

  ls -t "${ipas[@]}" | head -1
}
