# shrimpsend-ops（私有运维配置）

本目录用于存放**不应进入公开 Git 仓库**的生产配置。维护者使用私有仓库 [`git@github.com:shrimpsend/ops.git`](https://github.com/shrimpsend/ops)，在部署/打包机上 clone 到业务仓旁，设置：

```bash
git clone git@github.com:shrimpsend/ops.git /path/to/shrimpsend-ops
export ULTRASEND_OPS_DIR=/path/to/shrimpsend-ops
```

## 目录结构

```
ops/
├── cn/                          # 国内 (xiachuan)
│   ├── application-prod.yml
│   └── config.prod.bare.json
├── overseas/                    # 海外 (ShrimpSend)
│   ├── application-prod-overseas.yml
│   └── config.prod-overseas.bare.json
├── local/                       # 本地调试（Centrifugo、dev-overseas、backend.env）
│   ├── config.json
│   ├── backend.env
│   ├── application-dev-overseas.yml
│   └── docker.env               # 可选
├── flutter/
│   ├── openpanel_env.secrets.dart   # OpenPanel client id/secret/ingest URL
│   ├── env.secrets.dart             # RevenueCat 公钥、生产 API/WS URL
│   └── build.env                    # Stripe Price 等构建时 dart-define 源（可选）
├── web/
│   └── .env.local               # Stripe Price + OpenPanel Web
├── harmonyos/
│   └── build-profile.json5
└── scripts/
    ├── sync-to-build-machine.sh
    └── sync-to-local.sh
```

## 本地调试（一键同步 + 建库）

维护者 clone 业务仓后，从 `ops/local/` 同步团队本地配置并初始化 MySQL：

```bash
./scripts/deploy-local.sh
# 等价于 ./ops/scripts/sync-to-local.sh
# 仅同步配置、跳过建库：./scripts/deploy-local.sh --skip-db
```

同步目标：

| ops/local | 业务仓 |
|-----------|--------|
| `config.json` | `config.json` |
| `application-dev-overseas.yml` | `backend/src/main/resources/application-dev-overseas.yml` |
| `backend.env` | `backend/.env` |
| `docker.env` | `.env`（Docker Compose） |
| `web/.env.local` 或 `ops/web/.env.local` | `web/.env.local` |

启动（Centrifugo + 后端 + Web 一键）：

- 国内：`./scripts/start-dev.sh`（默认 profile，`ultrasend` 库）
- 海外：`./scripts/start-dev.sh --overseas`（`dev-overseas`，`ultrasend_overseas` 库）
- 停止：`./scripts/stop-dev.sh`

仅调试后端（不启 Centrifugo/Web）：`backend/scripts/run-dev-overseas.sh`

## 同步到业务仓（部署 / 打包前）

```bash
./ops/scripts/sync-to-build-machine.sh
# 或从独立 ops 仓：
ULTRASEND_OPS_DIR=../shrimpsend-ops ./scripts/deploy.sh
```

`ops/flutter/env.secrets.dart` 含 RevenueCat SDK 公钥（`test_`/`appl_`/`goog_`）与生产 API/WS URL；构建脚本亦支持通过环境变量 `--dart-define` 覆盖（见 `app/scripts/dart-define-env-secrets.sh`）。

## 凭证轮换清单（开源公开前必须完成）

以下凭证曾出现在 Git 历史中，**公开前请全部轮换**：

| 服务 | 轮换位置 |
|------|----------|
| MySQL | 国内 / 海外数据库密码 |
| JWT | `access-secret` / `refresh-secret`（国内与海外独立） |
| 消息加密 | `APP_MESSAGES_ENCRYPTION_KEY_BASE64` |
| 支付宝 | RSA 私钥（最高优先级） |
| Stripe | `sk_live_*`、`whsec_*` |
| RevenueCat | Webhook Bearer token |
| RevenueCat SDK 公钥 | `ops/flutter/env.secrets.dart`（虽为客户端公钥，开源前建议轮换或移出源码历史） |
| Cloudflare R2 | access-key-id / secret-access-key |
| 腾讯云 COS / SMS | SecretId / SecretKey |
| SendCloud | api-key |
| Centrifugo | HMAC secret、admin password、HTTP API key（国内/海外独立） |
| OpenPanel | `ops/web/.env.local`、`ops/flutter/openpanel_env.secrets.dart` |
| HarmonyOS | keystore storePassword / keyPassword |

轮换完成后更新本目录内对应文件，再执行 `sync-to-build-machine.sh` 同步到业务仓。
