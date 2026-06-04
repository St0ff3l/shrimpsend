#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 build.py --app-windows-only
