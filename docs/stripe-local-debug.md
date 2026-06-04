# Stripe 本地调试

适用于海外集群计费（后端 `StripeMembershipController`）：Checkout、订阅变更等事件通过 Webhook 同步会员权益。本地开发需把 Stripe 的事件转发到本机后端。

## 前置条件

- 安装 [Stripe CLI](https://stripe.com/docs/stripe-cli)。
- 登录：`stripe login`（选择正确的 Stripe 账号 / 测试模式）。
- 后端以 **海外** 配置启动，且监听 **`localhost:9000`**（与下文转发地址一致）。
- 环境变量配置测试用 **`STRIPE_SECRET_KEY`**（`sk_test_...`），与 Dashboard 测试数据一致。

## Webhook 转发（常用命令）

在终端保持运行，将 Stripe 测试环境事件转发到本地 Webhook：

```bash
stripe listen --forward-to localhost:9000/api/membership/stripe/webhook
```

- **路径**：与后端 `POST /api/membership/stripe/webhook` 一致。
- **端口**：若本地后端不是 `9000`，请同时修改上述 URL 中的端口。

## Webhook 签名密钥（必配）

`stripe listen` 启动后，终端会输出一行类似：

```text
Ready! Your webhook signing secret is whsec_xxxxxxxxxxxxx
```

后端验签使用配置项 **`STRIPE_WEBHOOK_SECRET`**（对应 `OverseasBillingProperties`，YAML 中为 `app.membership.overseas.stripe-webhook-secret`）。**每次新开 `stripe listen`，签名 secret 可能变化**，请把终端里打印的 `whsec_...` 同步到本地环境变量或 `application-dev-overseas.yml`，否则日志会出现 Webhook 签名校验失败。

## 验证流程建议

1. 启动 `stripe listen`（见上文命令）。
2. 更新本地 `STRIPE_WEBHOOK_SECRET` 与 CLI 输出一致后重启后端。
3. 在测试模式下完成一次 Checkout / 订阅变更，观察后端日志与 Stripe CLI 是否显示已转发事件。
4. 需要时可使用 CLI 触发示例事件（具体事件类型以 Stripe 文档为准），例如：`stripe trigger checkout.session.completed`（若账号与 CLI 版本支持）。

## 相关代码与配置

- Webhook 入口：`backend/.../StripeMembershipController.java`（`/api/membership/stripe/webhook`）。
- 本地海外示例配置：`backend/src/main/resources/application-dev-overseas.yml`（含 Stripe URL 与密钥占位说明）。

## 其他说明

- 仅 **`clusterDeploymentService.isOverseasDeployment()`** 为 true 时 Webhook 才会处理业务；本地请使用海外部署 profile。
- 生产环境应在 Stripe Dashboard 配置固定 Endpoint 与 Webhook signing secret，不要使用 `stripe listen`。
