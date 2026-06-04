#!/usr/bin/env python3
"""Download WenYuan Sans SC VF for Windows Flutter builds."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_WINDOWS_FONTS = ROOT / "app" / "assets" / "fonts" / "windows"
LICENSES = Path(__file__).resolve().parent / "LICENSES"

WENYUAN_RELEASE = "2026.5.22"
WENYUAN_TTF_URL = (
    f"https://github.com/takushun-wu/WenYuanFonts/releases/download/"
    f"{WENYUAN_RELEASE}/WenYuanSansSCVF.ttf"
)
OUTPUT_NAME = "WenYuanSansSCVF.ttf"

OFL_NOTICE = """Ultrasend Windows builds bundle WenYuan Sans SC / 文源黑体 (SIL Open Font License 1.1).

Source: https://github.com/takushun-wu/WenYuanFonts
Derived from Source Han Sans. Free for commercial use under OFL 1.1.
"""


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"  -> {dest.name}")
    result = subprocess.run(
        ["curl", "-fsSL", "-o", str(dest), url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"curl failed for {url}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--app-windows-only",
        action="store_true",
        help="Install font only under app/assets/fonts/windows/",
    )
    args = parser.parse_args()
    if not args.app_windows_only:
        print("Only --app-windows-only is supported.", file=sys.stderr)
        return 1

    LICENSES.mkdir(parents=True, exist_ok=True)
    staging = Path(__file__).resolve().parent / ".staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()

    dest = APP_WINDOWS_FONTS / OUTPUT_NAME
    if dest.exists() and dest.stat().st_size > 1_000_000:
        print(f"Reuse existing {dest}")
    else:
        print("Downloading WenYuan Sans SC VF...")
        try:
            download(WENYUAN_TTF_URL, staging / OUTPUT_NAME)
        except Exception as exc:  # noqa: BLE001
            print(f"FAILED {OUTPUT_NAME}: {exc}", file=sys.stderr)
            return 1
        APP_WINDOWS_FONTS.mkdir(parents=True, exist_ok=True)
        shutil.copy2(staging / OUTPUT_NAME, dest)

    (LICENSES / "NOTICE.txt").write_text(OFL_NOTICE, encoding="utf-8")
    if staging.exists():
        shutil.rmtree(staging)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
