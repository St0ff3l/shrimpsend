# 国内版 iOS RevenueCat 配置与验证

虾传（`prod` / `api.xiachuan.net`）iOS **cn** 包（`dev.ultrasend.app.cn`）终身买断走 **RevenueCat + App Store**；Android / Web 仍走 **支付宝**（见 [membership-payment.md](./membership-payment.md)）。

国际 **intl** 包订阅配置见 [revenuecat-overseas-setup.md](./revenuecat-overseas-setup.md)。

## 1. RevenueCat Dashboard（国内独立 Project）

与 ShrimpSend 海外 Project **分离**（Webhook 分别指向 `api.xiachuan.net` / `api.shrimpsend.com`）。

| 步骤 | 说明 |
|------|------|
| Project | 虾传 / Xiachuan CN（独立 Project） |
| 绑定 Apple App | Bundle ID：`dev.ultrasend.app.cn` |
| ASC 关联 | App Store Connect API Key 或 Shared Secret |
| Products | 在售 2 个 IAP（Pro + 增购）；Mini / 升级包仅 webhook 兼容 |
| Webhook | URL 见第 3 节；Authorization Bearer token |
| app_user_id | 后端 numeric userId（登录后 `Purchases.logIn(userId)`） |

**说明**：客户端不使用 Offering / Entitlement identifier，直接 `Purchases.getProducts([productId])`。

### 终身 IAP Product ID

**新用户仅购买 Pro + 增购**；Mini 已停售，下列 Mini 相关 ID 仅用于存量用户 webhook 兼容（客户端无购买入口）。

| 档位 | Product ID | 参考价 (CNY) | ASC 类型 | 说明 |
|------|------------|--------------|----------|------|
| Pro 终身 | `ultrasend_pro_lifetime` | ¥60 | Non-Consumable | **在售** |
| 增购 +5 设备 | `ultrasend_addon_5_devices` | ¥45 | **Consumable** | **在售**，需已开通 Mini 或 Pro |
| Mini→Pro 升级 | `ultrasend_mini_to_pro_upgrade` | ¥30 | Non-Consumable | 已停售，webhook 兼容 |
| Mini 终身 | `ultrasend_mini_lifetime` | ¥30 | Non-Consumable | 已停售，webhook 兼容 |

### RC 配置自检清单

- [ ] Apple App Bundle ID = `dev.ultrasend.app.cn`
- [ ] 在售 Product ID（Pro + 增购）与 ASC 一致；Mini / 升级包按需保留供 webhook
- [ ] Webhook URL = `https://api.xiachuan.net/api/membership/revenuecat/webhook`
- [ ] Webhook Authorization 与服务器 `REVENUECAT_WEBHOOK_AUTH` 一致
- [ ] 已记录 cn 专用 `appl_` 公钥（写入构建环境变量，见第 4 节）

## 2. App Store Connect

App 与 3 个 IAP 商品创建完成后，提审前还需：

- [ ] 沙盒测试员（Users and Access → Sandbox）
- [ ] IAP 简体中文名称/描述（注明会员中心有「恢复购买」）
- [ ] IAP 审核截图（**已登录**状态下的购买流程）
- [ ] IAP 与 App 版本一并提交
- [ ] Paid Applications Agreement / 银行税务信息完整

Apple Developer 双 Bundle 签名见 [ios-dual-bundle-apple-setup.md](./ios-dual-bundle-apple-setup.md)。

## 3. 后端 Webhook

| 环境 | URL |
|------|-----|
| 生产 | `POST https://api.xiachuan.net/api/membership/revenuecat/webhook` |
| 本地 | `POST http://127.0.0.1:9000/api/membership/revenuecat/webhook`（ngrok 转发） |

**鉴权**：RevenueCat Dashboard → Webhooks → Authorization header 设为 `Bearer <token>`，与服务器环境变量一致：

```bash
export REVENUECAT_WEBHOOK_AUTH="<your-secret-token>"
# application-prod.yml → app.membership.revenuecat.webhook-auth
```

国内 handler 支持 RC 嵌套 `event` 对象（[`RevenueCatDomesticWebhookParser`](../backend/src/main/java/dev/ultrasend/backend/membership/RevenueCatDomesticWebhookParser.java)），幂等键：`REVENUECAT` + `RC:{transactionId}:{productId}`。

### Webhook 探测脚本

```bash
export REVENUECAT_WEBHOOK_AUTH="<token>"
export TEST_USER_ID=123
./backend/scripts/test-revenuecat-cn-webhook.sh
```

## 4. Flutter cn 包编译

[`app/lib/config/env.dart`](../app/lib/config/env.dart) 按 flavor 选择 RC Apple 公钥（值来自 gitignored `env.secrets.dart` 或环境变量）：

| 包 | release Apple key |
|----|-------------------|
| cn（`OVERSEAS_BUILD=false`） | 国内 Project `appl_…`（`RC_APPLE_API_KEY_CN`） |
| intl（`OVERSEAS_BUILD=true`） | 海外 Project `appl_…`（`RC_APPLE_API_KEY_INTL`） |
| debug/profile | Test Store `test_…`（`RC_TEST_STORE_API_KEY`） |

```bash
# cn release IPA（从 ops/flutter/env.secrets.dart sync，或 export 覆盖）
# export RC_APPLE_API_KEY_CN=appl_xxxxxxxx
cd app
./scripts/build-ios.sh ipa

# intl release（不变）
./scripts/build-ios.sh --overseas ipa
```

| 可选 dart-define | 说明 |
|------------------|------|
| `RC_PRODUCT_PRO` / `RC_PRODUCT_ADDON_5` | 覆盖默认 `ultrasend_*`（`RC_PRODUCT_MINI` 可选，客户端不购买） |

## 5. 登录策略

**先登录、后购买**（非消耗型 / 消耗型均不要求免登录）。Webhook 的 `app_user_id` 必须是 backend userId。

## 6. 端到端验证清单

### 6.1 沙盒购买

前置：cn release/TestFlight 包 + 沙盒 Apple ID + 虾传账号已登录。

- [ ] FREE 用户：会员中心仅见 Pro ¥60 + 增购（增购按钮禁用，提示「请先开通 Pro 会员」）
- [ ] 会员中心购买 Pro → StoreKit 沙盒成功
- [ ] 30 秒内 `/api/membership/me` → `tierCode=PRO`，`paymentChannel=APPLE_RC`
- [ ] `membership_order_events` 有 `provider=REVENUECAT`
- [ ] 存量 MINI 用户：当前档位显示 Mini；仅见增购 ¥45，**无 Pro 卡片**
- [ ] PRO 用户：仅见增购
- [ ] 已开通 Mini/Pro 后购买增购包 → `deviceLimit` +5

### 6.2 恢复购买

- [ ] 会员中心「恢复购买」→ 重装后 tier 恢复
- [ ] 无购买记录账号恢复 → tier 仍为 FREE

### 6.3 Webhook 手动探测

见第 3 节 `test-revenuecat-cn-webhook.sh`；重复发送应 `changed=false`（幂等）。

### 6.4 与支付宝互斥

国内 Android 不初始化 RC；iOS `APPLE_RC` 与 Android `ALIPAY_LIFETIME` 为不同渠道，互不影响。

## 7. 相关文档

- [membership-payment.md](./membership-payment.md) — 买断/支付总览
- [ios-dual-bundle-apple-setup.md](./ios-dual-bundle-apple-setup.md) — 双 Bundle 签名
- [revenuecat-overseas-setup.md](./revenuecat-overseas-setup.md) — intl 订阅 RC
