# 出海版 RevenueCat 配置与验证

ShrimpSend（`prod-overseas` / `api.shrimpsend.com`）移动端订阅走 **RevenueCat + App Store / Google Play**；Web / 桌面走 **Stripe**（见 [membership-payment.md](./membership-payment.md)）。

## 1. RevenueCat Dashboard

| 步骤 | 说明 |
|------|------|
| 创建/选择项目 | ShrimpSend 海外 |
| 绑定 Apple App | iOS **intl** 包 Bundle ID：`dev.ultrasend.app`；国内 **cn** 包 `dev.ultrasend.app.cn` 终身 IAP 见 [revenuecat-cn-ios-setup.md](./revenuecat-cn-ios-setup.md) |
| 绑定 Google App | Android 包名 + Play 服务账号 JSON |
| 获取 API Keys | Apple 公钥（`appl_…`）、Google 公钥（`goog_…`） |
| 配置 Products | 6 个订阅商品 ID（见下表），与 App Store Connect / Play Console 一致 |
| 配置 Webhook | URL 见下节；Authorization 填 Bearer token |
| app_user_id | 使用后端 numeric userId（App 登录后 `Purchases.logIn(userId)`） |

**说明**：客户端不使用 Offering / Entitlement identifier，直接按 Product ID 调用 `Purchases.getProducts()`。Dashboard 中 Offering 可按 RC 惯例配置，但不影响 App 逻辑。

### 订阅 Product ID（默认）

| 档位 | Product ID |
|------|------------|
| Plus 月付 | `shrimpsend_plus_monthly` |
| Plus 年付 | `shrimpsend_plus_yearly` |
| Pro 月付 | `shrimpsend_pro_monthly` |
| Pro 年付 | `shrimpsend_pro_yearly` |
| Ultra 月付 | `shrimpsend_ultra_monthly` |
| Ultra 年付 | `shrimpsend_ultra_yearly` |

## 2. App Store Connect / Google Play Console

在两家商店分别创建与上表 **完全一致** 的 6 个自动续订订阅商品，并：

1. 配置订阅组、价格（USD）、本地化描述
2. 沙盒测试账号（Apple）/ 许可测试人员（Google）
3. 将商品 ID 同步到 RevenueCat Dashboard Products

## 3. 后端 Webhook

| 环境 | URL |
|------|-----|
| 生产 | `POST https://api.shrimpsend.com/api/membership/revenuecat/webhook` |
| 本地 | `POST http://127.0.0.1:9000/api/membership/revenuecat/webhook`（可用 ngrok 转发） |

**鉴权**：RevenueCat Dashboard → Webhooks → Authorization header 设为 `Bearer <token>`，与服务器环境变量一致：

```bash
export REVENUECAT_WEBHOOK_AUTH="<your-secret-token>"
# application-prod-overseas.yml 读取 app.membership.revenuecat.webhook-auth
```

本地调试：

```bash
# 全栈（Centrifugo + dev-overseas 后端 + Web）
./scripts/start-dev.sh --overseas

# 另开终端：Stripe webhook（会员）
stripe listen --forward-to localhost:9000/api/membership/stripe/webhook

# RevenueCat webhook 本地（示例）
ngrok http 9000
# RevenueCat 临时 webhook → https://xxxx.ngrok-free.app/api/membership/revenuecat/webhook
export REVENUECAT_WEBHOOK_AUTH="local-dev-token"
```

## 4. Flutter 出海包编译

RevenueCat 公钥与生产 API URL 见 gitignored [`app/lib/config/env.secrets.dart`](../app/lib/config/env.secrets.dart)（从 `ops/flutter/` sync）；[`env.dart`](../app/lib/config/env.dart) 通过 `--dart-define` 或 secrets 引用：

| 配置 | 用途 |
|------|------|
| `RC_TEST_STORE_API_KEY` / secrets | 本地 `flutter run` / profile（`kReleaseMode == false`） |
| `RC_APPLE_API_KEY_INTL` / secrets | iOS intl release（`appl_` 前缀） |
| `RC_GOOGLE_API_KEY` / secrets | Android release（`goog_` 前缀，可空则回退 Apple 正式 key） |

构建脚本亦支持环境变量注入（见 [`app/scripts/dart-define-env-secrets.sh`](../app/scripts/dart-define-env-secrets.sh)）。

```bash
# 本地 debug：自动 Test Store，无需额外参数
flutter run --dart-define=OVERSEAS_BUILD=true

# 线上 release
./app/scripts/build-ios.sh --overseas
./app/scripts/build-android.sh --overseas play
```

| 配置 | 说明 |
|------|------|
| `rcStoreMode` | 启动日志可见：`test` 或 `prod` |
| `OVERSEAS_BUILD=true` | 构建脚本 `--overseas` 自动注入 |
| `RC_PLUS_MONTHLY` … `RC_ULTRA_YEARLY` | 可选 dart-define，覆盖默认 `shrimpsend_*` |

后端商品 ID 环境变量（与 Flutter 对齐）：`OVERSEAS_RC_PLUS_MONTHLY` … `OVERSEAS_RC_ULTRA_YEARLY`。

## 5. Webhook 事件处理（海外）

后端 [`OverseasSubscriptionService`](../backend/src/main/java/dev/ultrasend/backend/service/OverseasSubscriptionService.java) 行为：

| RC 事件 | 行为 |
|---------|------|
| `INITIAL_PURCHASE` / `RENEWAL` / 升级等 | 按 product_id 写入 `membership_entitlements` |
| `EXPIRATION` | 降级为 FREE |
| `REFUND` / `REVOKE` | 立即降级为 FREE |
| `CANCELLATION` | 保留至周期结束，等 `EXPIRATION` |
| `BILLING_ISSUE` | 仅日志告警 |

幂等键：`REVENUECAT_OS` + `RC_EVT:{eventId}`

## 6. 端到端验证清单

### 6.1 购买（iOS / Android）

- [ ] 登录账号，确认 `Purchases.logIn(userId)` 与后端 userId 一致
- [ ] 会员中心选择档位并完成商店购买
- [ ] App 显示「购买成功，权益将由服务器同步」并开始轮询
- [ ] 30 秒内 `/api/membership/me` 返回正确 `tierCode`、`paymentChannel`（`APPLE_RC` / `GOOGLE_RC`）
- [ ] `membership_order_events` 有 `REVENUECAT_OS` 记录

### 6.2 恢复购买

- [ ] 会员中心点击「恢复购买」
- [ ] 已有订阅账号权益恢复；无订阅账号提示同步完成但 tier 仍为 FREE

### 6.3 取消与到期

- [ ] 在 App Store / Play 取消订阅 → 当前周期内 tier 保持
- [ ] 周期结束后收到 `EXPIRATION` webhook → tier 降为 FREE

### 6.4 退款

- [ ] 沙盒发起退款（或模拟 `REFUND` webhook）
- [ ] 后端立即 `downgradeToFree`，`/membership/me` tier 为 FREE

### 6.5 跨渠道互斥

- [ ] 已有 Stripe 活跃订阅时，App 内 RC 购买被拦截或记录 `subscription_conflicts`
- [ ] 桌面/Web 对 `APPLE_RC` / `GOOGLE_RC` 用户隐藏 Stripe 购买入口

### 6.6 本地 Webhook 调试

```bash
curl -X POST http://127.0.0.1:9000/api/membership/revenuecat/webhook \
  -H "Authorization: Bearer $REVENUECAT_WEBHOOK_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "id": "test-evt-001",
      "type": "INITIAL_PURCHASE",
      "app_user_id": "123",
      "product_id": "shrimpsend_plus_monthly",
      "store": "APP_STORE",
      "expiration_at_ms": 1893456000000
    }
  }'
```

将 `123` 换为真实 userId；重复发送应被幂等跳过。

## 7. 相关文档

- [membership-payment.md](./membership-payment.md) — 双轨支付、渠道互斥
- [cross-platform-subscription-rollout.md](./cross-platform-subscription-rollout.md) — 上线顺序
- [stripe-local-debug.md](./stripe-local-debug.md) — Stripe 本地调试（Web/桌面）
