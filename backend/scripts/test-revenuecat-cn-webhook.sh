#!/usr/bin/env bash
# 国内 cn iOS RevenueCat Webhook 探测（部署后 / 沙盒 E2E 前执行）。
#
# 用法:
#   export REVENUECAT_WEBHOOK_AUTH="<与 RC Dashboard 一致的 token>"
#   export TEST_USER_ID=123
#   ./backend/scripts/test-revenuecat-cn-webhook.sh
#
# 可选:
#   WEBHOOK_URL=https://api.xiachuan.net/api/membership/revenuecat/webhook
#   PRODUCT_ID=ultrasend_mini_lifetime
#   TRANSACTION_ID=sandbox-txn-manual-001
set -euo pipefail

WEBHOOK_URL="${WEBHOOK_URL:-https://api.xiachuan.net/api/membership/revenuecat/webhook}"
PRODUCT_ID="${PRODUCT_ID:-ultrasend_mini_lifetime}"
TRANSACTION_ID="${TRANSACTION_ID:-sandbox-txn-manual-$(date +%s)}"
EVENT_ID="${EVENT_ID:-test-cn-$(date +%s)}"

if [[ -z "${TEST_USER_ID:-}" ]]; then
  echo "错误: 请设置 TEST_USER_ID（虾传账号 numeric userId）" >&2
  exit 1
fi

AUTH_HEADER=()
if [[ -n "${REVENUECAT_WEBHOOK_AUTH:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${REVENUECAT_WEBHOOK_AUTH}")
else
  echo "警告: REVENUECAT_WEBHOOK_AUTH 未设置，生产环境可能拒绝请求" >&2
fi

echo "POST ${WEBHOOK_URL}"
echo "  app_user_id=${TEST_USER_ID} product_id=${PRODUCT_ID} transaction_id=${TRANSACTION_ID}"

curl -sS -X POST "${WEBHOOK_URL}" \
  "${AUTH_HEADER[@]}" \
  -H "Content-Type: application/json" \
  -d "{
    \"event\": {
      \"id\": \"${EVENT_ID}\",
      \"type\": \"NON_RENEWING_PURCHASE\",
      \"app_user_id\": \"${TEST_USER_ID}\",
      \"product_id\": \"${PRODUCT_ID}\",
      \"transaction_id\": \"${TRANSACTION_ID}\",
      \"store\": \"APP_STORE\"
    }
  }"
echo
echo "重复发送同一 transaction_id 应被幂等跳过（changed=false）。"
