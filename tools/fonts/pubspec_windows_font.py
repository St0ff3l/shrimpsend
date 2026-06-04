#!/usr/bin/env python3
"""Toggle WenYuan font registration in app/pubspec.yaml (Windows builds only)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = ROOT / "app" / "pubspec.yaml"
BEGIN = "  # BEGIN_WINDOWS_FONT"
END = "  # END_WINDOWS_FONT"
ENABLED_BLOCK = """\
  fonts:
    - family: UltrasendWenYuanSansSC
      fonts:
        - asset: assets/fonts/windows/WenYuanSansSCVF.ttf
"""


def _read() -> str:
    return PUBSPEC.read_text(encoding="utf-8")


def _write(text: str) -> None:
    PUBSPEC.write_text(text, encoding="utf-8")


def _replace_block(text: str, inner: str) -> str:
    begin = text.find(BEGIN)
    end = text.find(END)
    if begin == -1 or end == -1 or end < begin:
        raise RuntimeError(f"Markers not found in {PUBSPEC}")
    before = text[: begin + len(BEGIN)]
    after = text[end + len(END) :]
    body = f"\n{inner.rstrip()}\n" if inner.strip() else "\n"
    return f"{before}{body}{END}{after}"


def is_enabled() -> bool:
    text = _read()
    begin = text.find(BEGIN)
    end = text.find(END)
    if begin == -1 or end == -1:
        return False
    inner = text[begin + len(BEGIN) : end].strip()
    return "fonts:" in inner


def enable() -> None:
    text = _replace_block(_read(), ENABLED_BLOCK)
    _write(text)
    print("pubspec: Windows font enabled")


def disable() -> None:
    text = _replace_block(_read(), "")
    _write(text)
    print("pubspec: Windows font disabled")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"enable", "disable", "status"}:
        print("Usage: pubspec_windows_font.py enable|disable|status", file=sys.stderr)
        return 1
    action = sys.argv[1]
    if action == "status":
        print("enabled" if is_enabled() else "disabled")
        return 0
    if action == "enable":
        enable()
    else:
        disable()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
