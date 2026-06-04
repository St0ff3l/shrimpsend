# 缤纷云详细配置（推荐）

[缤纷云](https://www.bitiful.com/) 是虾传**最推荐**的自建 S3 服务商：兼容 S3 API、可先使用后付费，存储与流量价格通常低于主流云厂商。可参考官方 [价格对比](https://docs.bitiful.com/prices/compare)。

## 适用场景

- 希望控制对象存储成本，又需要稳定的 S3 兼容服务。
- 已有或愿意注册缤纷云账号，自行管理桶与密钥。

## 创建存储桶

1. 登录 [缤纷云控制台](https://console.bitiful.com/)。
2. 创建一个新桶；为安全起见，建议使用**私有桶**。

![创建存储桶步骤 1](/docs/s3/bitiful/01-create-bucket-1.png)

![创建存储桶步骤 2](/docs/s3/bitiful/02-create-bucket-2.png)

## 服务器地址 / 可用区

在桶信息页可查看**服务端点**与**服务可用区**：

![服务端点与可用区](/docs/s3/bitiful/03-endpoint-region.png)

- **Endpoint** **必须**填写 `https://s3.bitiful.net`，且**必须**包含 `https://` 协议前缀。
- **Region** 填写控制台显示的**服务可用区**代码。

## 创建 Access Key / Secret Key

1. **添加子账户**（**子账户名称不能与桶名称相同**）：

![添加子账户](/docs/s3/bitiful/04-sub-account.png)

2. 为子账户**授予读写权限**：

![授予读写权限](/docs/s3/bitiful/05-grant-permissions.png)

3. **添加 Key**，保存 Access Key 与 Secret Key：

![添加 Key 1](/docs/s3/bitiful/06-add-key-1.png)

![添加 Key 2](/docs/s3/bitiful/07-add-key-2.png)

## 配置 CORS

Web 端直传需配置桶 CORS。**来源 Origin** 至少包含：

```text
https://shrimpsend.com
```

如有 `www` 子域，请一并添加 `https://www.shrimpsend.com`。**操作 Methods** 勾选 `GET`、`PUT`、`POST`、`DELETE`、`HEAD`。

## 填写虾传设置

有两种入口（二选一）：

1. **设置 → S3** — 全局保存，同账号各设备共用。
2. **S3 云端中转会话** — 在会话内打开 **S3 设置** 填写。

| 字段 | 说明 |
| --- | --- |
| Endpoint | **必须**为 `https://s3.bitiful.net`（含 `https://`） |
| Region | 服务可用区 |
| Bucket | 桶名称 |
| Path-style 访问 | **关闭** |
| Access Key ID / Secret Access Key | 子账户 Key |

![虾传 S3 设置页（缤纷云示例）](/docs/s3/bitiful/08-shrimpsend-settings.png)

## 测试连接

保存后点击「测试连接」，并确认 CORS、Region 与子账户权限无误。

## 相关链接

- [缤纷云官网](https://www.bitiful.com/)
- [缤纷云文档](https://docs.bitiful.com/)
