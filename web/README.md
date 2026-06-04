This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## OpenPanel（浏览器端）

- 公网：默认按 **hostname / API 根 URL** 判断是否走出海 ingest；自定义域名部署到海外时若 hostname 不含 `shrimpsend`，请设置 `NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER=intl`。
- 本地 `localhost` 等：仅当设置里开启「从本机连远程 prod」时启用——`mainland` 走国内 OpenPanel，`overseas` 走出海 OpenPanel；关闭远程时不上报，避免误打看板。

**公网走「出海」ingest 的条件（满足任一）**：`NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER=intl`，或 `hostname` 含 `shrimpsend`，或当前 `getApiUrl()` 含 `shrimpsend.com`。若判定为出海但未配置 `NEXT_PUBLIC_OPENPANEL_INTL_CLIENT_ID`，OpenPanel **不会初始化**（浏览器控制台会有一条警告）；请为对应环境写入 INTL 的 id/secret，或显式设 `NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER=cn` 走国内 ingest。

环境变量（`NEXT_PUBLIC_*` 会打进前端 bundle，由 CI / 部署配置即可）：

| 变量 | 说明 |
| --- | --- |
| `NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER` | 可选，强制 `intl` 或 `cn`（海外自定义域名务必按需设为 `intl`） |
| `NEXT_PUBLIC_OPENPANEL_CLIENT_ID` | 国内 Web client id；默认见 `.env` |
| `NEXT_PUBLIC_OPENPANEL_CLIENT_SECRET` | 国内 Web client secret；ingest 校验需要；默认见 `.env` |
| `NEXT_PUBLIC_OPENPANEL_API_URL` | 可选；国内 ingest 根路径，默认 `https://openpanel.sdtsdt.net/api` |
| `NEXT_PUBLIC_OPENPANEL_INTL_CLIENT_ID` | 出海 Web client id；默认见 `.env` |
| `NEXT_PUBLIC_OPENPANEL_INTL_CLIENT_SECRET` | 出海 Web client secret |
| `NEXT_PUBLIC_OPENPANEL_INTL_API_URL` | 可选；出海 ingest，默认 `https://openpanel.shrimpsend.com/api` |

### 自定义事件（与 Flutter 同名 `snake_case`）

封装：`src/lib/analytics.ts`（`analyticsTrack`）、事件名 `src/lib/analyticsEvents.ts`。路由级 `screenView` 由 `OpenPanelRouteTracker` 等现有逻辑负责；自定义事件覆盖登录、聊天会话、会员、设备、搜索、设置等。属性不含密码或密钥。

| 事件名 | 含义 | 常见属性（节选） |
| --- | --- | --- |
| `chat_session_open` | 在侧栏选中一条会话（含 S3） | `session_type`：`peer` / `s3` |
| `chat_text_send` / `chat_text_retry` | 文本发送/重试（主站 `ChatContext`） | `result`、`channel`、`length_bucket` |
| `login_submit` | 登录提交 | `result`、`auth_mode` |
| `register_submit` | 注册提交 | `result` |
| `logout` | 退出登录 | `api_logout_ok`（后端注销是否成功） |
| `qr_login_outcome` | Web 扫码登录 | `result` |
| `device_remove` | 删除设备 | `result` |
| `message_search` | 消息搜索 | `result`、`result_count` 或 bucket |
| `membership_screen_view` / `membership_purchase_start` / `membership_purchase_outcome` | 会员页与购买 | `tier_count`、`provider`、`result` 等 |
| `setting_changed` | 外观/语言/账户密码等 | `key`、`result`（如 `account_password`） |
| `s3_settings_save` | S3 配置保存 | `result` |

**验收建议**：选中会话后发一条文字、登录成功/失败、会员页进入、一次设置或 S3 保存后，在 OpenPanel 核对事件；未初始化 client 时调用 `analyticsTrack` 应静默 no-op。

## Getting Started

**Full stack (recommended):** from the repository root, start Centrifugo, backend, and Web together:

```bash
./scripts/start-dev.sh              # China logic
# ./scripts/start-dev.sh --overseas # ShrimpSend / overseas logic
```

See [docs/README.zh-CN.md](../docs/README.zh-CN.md) or [README.md](../README.md) for setup (`setup-local-config.sh` / `deploy-local.sh`) and production deploy.

**Web only** (backend already running):

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
