#!/usr/bin/env bash
# 停止由 start-dev.sh 启动的 Centrifugo、后端、Web 进程

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT/scripts/.dev-pids"

if [ ! -f "$PID_FILE" ]; then
  echo "未找到 .dev-pids，没有由 start-dev.sh 启动的进程需要停止。"
  exit 0
fi

echo "停止本地开发进程..."
while read -r pid; do
  [ -z "$pid" ] && continue
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "  已发 SIGTERM: PID $pid"
  fi
done < "$PID_FILE"

# 给 Gradle/Java 一点时间退出，若有子进程也一并结束
sleep 2
while read -r pid; do
  [ -z "$pid" ] && continue
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi
done < "$PID_FILE"

rm -f "$PID_FILE"
echo "已停止。"
echo "若仍有进程残留，可检查并结束占用 8000 / 9000 / 3000 端口的进程。"
