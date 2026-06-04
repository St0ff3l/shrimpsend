#!/usr/bin/env bash
# Optional QA: list likely user-visible CJK string literals under app/lib (excludes l10n ARB and comments-only files).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) not found" >&2
  exit 1
fi
rg -n --glob '*.dart' --glob '!l10n/generated/**' --glob '!**/*.g.dart' '[\p{Han}]' "$ROOT/lib" || true
