# 跨平台订阅渠道亲和 —— 上线 / 灰度 / 监控

本次改动覆盖：DB 加 `payment_channel`、`subscription_conflicts` 表、后端冲突检测、桌面端 Stripe / 支付宝 PC 网页支付、Flutter 与 Web 互斥 UI、i18n。详见 [membership-payment.md](./membership-payment.md) 的「跨平台渠道亲和」与「桌面端支付路径」章节。

## 上线顺序

1. **数据库迁移**
   - 执行 [`backend/scripts/migration-membership-payment-channel.sql`](../backend/scripts/migration-membership-payment-channel.sql)：加 `payment_channel` 列 + 索引、`subscription_conflicts` 表、回填历史用户。
   - 验证：`SELECT payment_channel, COUNT(*) FROM membership_entitlements GROUP BY 1;` 应看到 FREE / APPLE_RC / STRIPE / ALIPAY_LIFETIME 分布合理。
2. **后端先发**
   - 部署 Spring Boot，验证：
     - `GET /api/membership/me` 返回 `paymentChannel` / `canSwitchChannel`。
     - `GET /api/membership/cross-platform-hint` 按渠道返回 `manageTarget` + `messageKey`。
     - 新 RC webhook 写入会带 store 区分；制造冲突场景看 `subscription_conflicts` 是否产生记录、日志是否告警。
   - 配置 `app.membership.alipay.app-id/private-key/alipay-public-key` 后 `alipayPcPayUrl` 会随订单一起返回；未配置时回退 `alipayPayUrl`。
3. **Web 端发布**
   - 部署 Next.js，验证 APPLE_RC / GOOGLE_RC 用户访问 `/settings/membership` 看到锁定 Alert + 按钮禁用。
4. **App 端发布**（iOS / Android / 桌面）
   - 桌面端用户走 Stripe Checkout / 支付宝 PC 网页支付，端到端跑通。
   - Stripe-bound iOS 用户在 App 中应看到「网页 Stripe 订阅 → 管理订阅（网页）」按钮，RC 套餐按钮全部 disabled。
5. **灰度 1 周后清理**
   - 移除 Web 端 `upgradeRequiresApp` 临时分支（保留向后兼容期，灰度无问题再删）。

## 监控指标

| 指标 | 数据源 | 告警阈值（建议） |
|---|---|---|
| `subscription_conflicts` 新增条目数 | DB count(*) where detected_at > now()-1d | 单日 ≥ 3 立即告警 |
| 跨端跳转点击率（App banner → 浏览器） | 前端埋点 `membership.crossPlatformHint.click` | 持续观察，无阈值 |
| 桌面端 Stripe Checkout 转化率 | `create-checkout-session` 调用 vs 成功 webhook | 转化 < 30% 持续 3 天告警 |
| 桌面端支付宝 PC 转化率 | `createMembershipOrder(channel=ALIPAY)` from desktop UA vs `GRANTED` | 同上 |
| 客服「双订阅 / 重复扣费」工单数 | 工单系统 | 单周 ≥ 1 即复盘 |
| `/membership/me` 中 `paymentChannel == null` 比例 | 后端日志或定时聚合 | 应为 0，> 0 表示有未回填的存量数据 |

## 灰度策略

- 后端可控开关：本次改动均向后兼容（旧客户端忽略新字段）。建议直接全量发后端、再发前端。
- 若需更稳：在 `OverseasSubscriptionService.upsertSubscription` 加 `ff.subscription-affinity-enforce`（默认 true）feature flag，紧急情况下关闭冲突检测让 webhook 继续覆盖式写入。本次未默认引入 flag——监控里若发现冲突写入误报多，再补一个开关。

## 已知风险

- 桌面端 Stripe `success_url` 无 URL Scheme 唤起，依赖 5 分钟 `/membership/me` 轮询；若用户付完款后立即关掉 App 再打开，轮询会重置（下次进入 `_load()` 会重新拉 `me` 兜底）。
- RC 历史事件没有 `store` 字段的存量数据在回填 SQL 中统一标 `APPLE_RC`，可能少数 Android 海外用户被误标；新 webhook 进入后会按 `store` 字段更正。
- App Store 法规变化：US/EEA 政策窗口期可能允许 iOS 内直接走 Stripe，但当前仍按「亲和」策略保守处理；后续如要让 iOS 也走 Stripe，可在 [`membership_channel_guard.dart`](../app/lib/services/membership_channel_guard.dart) 中放开 `boundToStripeManageOnWeb` 分支。

## 回滚预案

- DB 迁移可逆：`ALTER TABLE membership_entitlements DROP COLUMN payment_channel; DROP TABLE subscription_conflicts;`。
- 后端代码回滚：撤销 `OverseasSubscriptionService` 冲突检测，会回到「最后一次 webhook 静默覆盖」的旧行为，但 `payment_channel` 字段会保留 NULL，不影响读路径。
- 客户端回滚：移除桌面端 Stripe 入口与渠道锁定 banner，回到「桌面无购买入口」的旧版。Web 端保留旧 `upgradeRequiresApp` 文案。
