#!/usr/bin/env bash
# Enable/disable bundled WenYuan font for Windows Flutter builds only.
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$APP_ROOT/.." && pwd)"
PYTHON="${PYTHON:-python3}"

usage() {
  echo "Usage: $0 enable|disable|status" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage

case "$1" in
  enable)
    "$PYTHON" "$REPO_ROOT/tools/fonts/build.py" --app-windows-only
    "$PYTHON" "$REPO_ROOT/tools/fonts/pubspec_windows_font.py" enable
    ;;
  disable)
    "$PYTHON" "$REPO_ROOT/tools/fonts/pubspec_windows_font.py" disable
    ;;
  status)
    "$PYTHON" "$REPO_ROOT/tools/fonts/pubspec_windows_font.py" status
    ;;
  *)
    usage
    ;;
esac
