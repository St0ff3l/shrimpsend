#!/usr/bin/env python3
"""Run the vendored seo-audit-skill checks for UltraSend public web pages."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


REPO_ROOT = Path(__file__).resolve().parents[2]
SKILL_ROOT = Path(__file__).resolve().parent
BASIC_SCRIPTS = SKILL_ROOT / "seo-audit" / "scripts"
FULL_SCRIPTS = SKILL_ROOT / "seo-audit-full" / "scripts"


@dataclass(frozen=True)
class AuditTarget:
    url: str
    keyword: str


DEFAULT_TARGETS = (
    AuditTarget("https://xiachuan.net/zh", "跨设备文件传输"),
    AuditTarget("https://xiachuan.net/zh/docs/intro", "虾传主要功能介绍"),
    AuditTarget("https://shrimpsend.com/en", "cross-device file transfer"),
    AuditTarget("https://shrimpsend.com/en/docs/intro", "ShrimpSend key features"),
)


def with_origin(target: AuditTarget, origin: str | None) -> AuditTarget:
    if not origin:
        return target
    parsed = urlparse(target.url)
    normalized_origin = origin.rstrip("/")
    return AuditTarget(f"{normalized_origin}{parsed.path}", target.keyword)


def slugify_url(url: str) -> str:
    parsed = urlparse(url)
    path = parsed.path.strip("/").replace("/", "-")
    host = parsed.netloc.replace(".", "-")
    return f"{host}-{path}" if path else host


def run_check(command: list[str]) -> tuple[int, dict[str, object] | None, str]:
    env = os.environ.copy()
    if os.environ.get("SEO_AUDIT_ALLOW_PRIVATE"):
        env["SEO_AUDIT_ALLOW_PRIVATE"] = "1"
    completed = subprocess.run(command, capture_output=True, text=True, check=False, env=env)
    if completed.stdout.strip():
        try:
            return completed.returncode, json.loads(completed.stdout), completed.stderr.strip()
        except json.JSONDecodeError:
            return completed.returncode, None, completed.stdout.strip() + completed.stderr.strip()
    return completed.returncode, None, completed.stderr.strip()


def write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def summarize_status(payload: dict[str, object] | None) -> str:
    if not payload:
        return "error"
    if payload.get("error"):
        return "fail"

    statuses: list[str] = []

    def collect(value: object) -> None:
        if isinstance(value, dict):
            status = value.get("status")
            if isinstance(status, str):
                statuses.append(status)
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for item in value:
                collect(item)

    collect(payload)
    if any(status in {"fail", "error"} for status in statuses):
        return "fail"
    if any(status == "warn" for status in statuses):
        return "warn"
    if statuses:
        return "pass"
    return "info"


def run_target(target: AuditTarget, output_dir: Path) -> list[tuple[str, int, str]]:
    slug = slugify_url(target.url)
    checks = [
        (
            "site",
            [
                sys.executable,
                str(BASIC_SCRIPTS / "check-site.py"),
                target.url,
            ],
        ),
        (
            "page",
            [
                sys.executable,
                str(BASIC_SCRIPTS / "check-page.py"),
                target.url,
                "--keyword",
                target.keyword,
            ],
        ),
        (
            "schema",
            [
                sys.executable,
                str(BASIC_SCRIPTS / "check-schema.py"),
                target.url,
            ],
        ),
        (
            "social",
            [
                sys.executable,
                str(FULL_SCRIPTS / "check-social.py"),
                target.url,
            ],
        ),
    ]

    rows: list[tuple[str, int, str]] = []
    for name, command in checks:
        exit_code, payload, stderr = run_check(command)
        report = {
            "target": target.url,
            "keyword": target.keyword,
            "check": name,
            "exit_code": exit_code,
            "status": summarize_status(payload),
            "payload": payload,
            "stderr": stderr,
        }
        write_json(output_dir / f"{slug}-{name}.json", report)
        rows.append((f"{slug}-{name}", exit_code, report["status"]))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--phase",
        default="before",
        choices=("before", "after"),
        help="Report phase directory under docs/seo-audits.",
    )
    parser.add_argument(
        "--output-root",
        default=str(REPO_ROOT / "docs" / "seo-audits"),
        help="Directory that receives audit JSON and summary files.",
    )
    parser.add_argument(
        "--target-origin",
        help="Override target origin while keeping the default public paths, e.g. http://localhost:3010.",
    )
    parser.add_argument(
        "--allow-private",
        action="store_true",
        help="Allow auditing localhost/private addresses for local build verification.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_root) / args.phase
    output_dir.mkdir(parents=True, exist_ok=True)

    if args.allow_private:
        os.environ["SEO_AUDIT_ALLOW_PRIVATE"] = "1"

    summary_rows: list[tuple[str, int, str]] = []
    for target in DEFAULT_TARGETS:
        summary_rows.extend(run_target(with_origin(target, args.target_origin), output_dir))

    summary = ["# SEO Audit Summary", "", f"Phase: `{args.phase}`", ""]
    summary.extend(f"- `{name}`: exit `{exit_code}`, status `{status}`" for name, exit_code, status in summary_rows)
    (output_dir / "summary.md").write_text("\n".join(summary) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
