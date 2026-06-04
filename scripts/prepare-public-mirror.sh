#!/usr/bin/env bash
# 准备 GitHub 公开镜像：从 Git 历史中移除敏感文件（破坏性操作，执行前请完整备份）
#
# 前置条件:
#   pip install git-filter-repo  或  brew install git-filter-repo
#   已完成凭证轮换（见 ops/README.md）
#
# 用法:
#   ./scripts/prepare-public-mirror.sh --dry-run   # 仅列出将移除的路径
#   ./scripts/prepare-public-mirror.sh             # 执行 filter-repo（改写历史）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

PATHS=(
  backend/src/main/resources/application-prod.yml
  backend/src/main/resources/application-prod-overseas.yml
  backend/src/main/resources/application-dev-overseas.yml
  backend/.env
  config.json
  config.prod.bare.json
  config.prod-overseas.bare.json
  config.prod.json
  web/.env
  web/.env.local
  app/lib/config/openpanel_env.secrets.dart
  app/lib/config/env.secrets.dart
  app_ohos/build-profile.json5
)

echo "将从历史中移除的路径:"
printf '  - %s\n' "${PATHS[@]}"

if $DRY_RUN; then
  echo ""
  echo "Dry run — 未修改仓库。确认后运行: $0"
  exit 0
fi

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "错误: 未安装 git-filter-repo" >&2
  exit 1
fi

echo ""
echo "警告: 此操作将改写所有 commit hash。请确保已备份仓库。"
read -r -p "继续? (yes/no): " ans
if [ "$ans" != "yes" ]; then
  echo "已取消"
  exit 1
fi

ARGS=()
for p in "${PATHS[@]}"; do
  ARGS+=(--path "$p" --invert-paths)
done

git filter-repo "${ARGS[@]}" --force

echo ""
echo "历史清理完成。后续步骤:"
echo "  1. git remote add origin git@github.com:shrimpsend/shrimpsend.git"
echo "  2. git push -u origin main"
echo "  3. 在 GitHub 启用 Secret Scanning + Push Protection"
echo "  4. 协作者需 re-clone"
echo ""
echo "若已用 orphan main 迁到 GitHub，则无需再运行本脚本。"
