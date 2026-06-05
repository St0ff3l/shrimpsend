#!/usr/bin/env bash
# Shared helpers for resolving and validating the ultrasend ops config directory.

_ULTRASEND_OPS_MARKER="ultrasend-ops"
_ULTRASEND_OPS_SUBDIRS=(cn overseas local flutter web harmonyos)

ops_common_hint() {
  cat >&2 <<'EOF'
请获取 ops 配置目录：

  # 方式 A：clone 到业务仓平级目录（推荐）
  git clone git@github.com:shrimpsend/public-ops.git ../ops    # 公开样例
  # 或维护者私有仓
  git clone git@github.com:shrimpsend/ops.git ../ops

  # 方式 B：自定义路径
  export ULTRASEND_OPS_DIR=/path/to/your-ops

ops 根目录须包含 marker 文件 .ultrasend-ops（内容为 ultrasend-ops）
及至少一个配置子目录（cn/、overseas/、local/、flutter/、web/、harmonyos/）。
详见 ops/README.md
EOF
}

# is_valid_ultrasend_ops_dir DIR — return 0 if valid
is_valid_ultrasend_ops_dir() {
  local dir="$1"
  local marker="$dir/.ultrasend-ops"
  local first_line=""
  local sub=""

  [ -d "$dir" ] || return 1
  [ -f "$marker" ] || return 1

  first_line="$(sed -n '1p' "$marker" | tr -d '[:space:]')"
  [ "$first_line" = "$_ULTRASEND_OPS_MARKER" ] || return 1

  for sub in "${_ULTRASEND_OPS_SUBDIRS[@]}"; do
    if [ -d "$dir/$sub" ]; then
      return 0
    fi
  done
  return 1
}

# validate_ultrasend_ops_dir DIR — exit 1 if not a valid ultrasend ops root
validate_ultrasend_ops_dir() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    echo "错误: ops 目录不存在: $dir" >&2
    ops_common_hint
    exit 1
  fi

  if [ ! -f "$dir/.ultrasend-ops" ]; then
    echo "错误: 缺少 ops marker 文件: $dir/.ultrasend-ops" >&2
    echo "该目录不是有效的 ultrasend ops 配置仓。" >&2
    ops_common_hint
    exit 1
  fi

  if ! is_valid_ultrasend_ops_dir "$dir"; then
    local first_line
    first_line="$(sed -n '1p' "$dir/.ultrasend-ops" | tr -d '[:space:]')"
    if [ "$first_line" != "$_ULTRASEND_OPS_MARKER" ]; then
      echo "错误: ops marker 内容无效: $dir/.ultrasend-ops（期望首行为 ultrasend-ops）" >&2
    else
      echo "错误: ops 目录缺少预期子目录（cn/、overseas/、local/、flutter/、web/、harmonyos/ 至少其一）: $dir" >&2
    fi
    ops_common_hint
    exit 1
  fi
}

# try_resolve_ultrasend_ops_dir ROOT — print OPS_DIR on success, return 1 if not found
try_resolve_ultrasend_ops_dir() {
  local root="$1"
  local candidate=""

  if [ -n "${ULTRASEND_OPS_DIR:-}" ]; then
    candidate="$(cd "$ULTRASEND_OPS_DIR" 2>/dev/null && pwd || echo "$ULTRASEND_OPS_DIR")"
  elif [ -d "$root/../ops" ]; then
    candidate="$(cd "$root/../ops" && pwd)"
  else
    return 1
  fi

  if is_valid_ultrasend_ops_dir "$candidate"; then
    echo "$candidate"
    return 0
  fi
  return 1
}

# resolve_ultrasend_ops_dir ROOT — print absolute OPS_DIR to stdout; exit 1 on failure
resolve_ultrasend_ops_dir() {
  local root="$1"
  local candidate=""

  if [ -n "${ULTRASEND_OPS_DIR:-}" ]; then
    candidate="$(cd "$ULTRASEND_OPS_DIR" 2>/dev/null && pwd || echo "$ULTRASEND_OPS_DIR")"
  else
    candidate="$(cd "$root/.." 2>/dev/null && pwd)/ops"
  fi

  validate_ultrasend_ops_dir "$candidate"
  echo "$candidate"
}
