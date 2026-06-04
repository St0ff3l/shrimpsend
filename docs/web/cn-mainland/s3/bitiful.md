# 缤纷云详细配置（推荐）

[缤纷云](https://www.bitiful.com/) 是虾传**最推荐**的自建 S3 服务商：兼容 S3 API、可先使用后付费，存储与流量价格通常低于主流国内云厂商。可参考官方 [价格对比](https://docs.bitiful.com/prices/compare)。

## 适用场景

- 希望控制对象存储成本，又需要稳定的国内 S3 兼容服务。
- 已有或愿意注册缤纷云账号，自行管理桶与密钥。

## 创建存储桶

1. 登录 [缤纷云控制台](https://console.bitiful.com/)。
2. 创建一个新桶；为安全起见，建议使用**私有桶**。

![创建存储桶步骤 1](/docs/s3/bitiful/01-create-bucket-1.png)

![创建存储桶步骤 2](/docs/s3/bitiful/02-create-bucket-2.png)

## 服务器地址 / 可用区

在桶信息页可查看**服务端点**与**服务可用区**：

![服务端点与可用区](/docs/s3/bitiful/03-endpoint-region.png)

- **Endpoint** **必须**填写 `https://s3.bitiful.net`，地址中**必须**包含 `https://` 协议前缀，不可省略或使用 `http://`。
- **Region** 填写控制台显示的**服务可用区**代码，与 Endpoint 一一对应。

## 创建 Access Key / Secret Key

1. **添加子账户**（注意：**子账户名称不能与桶名称相同**，否则会导致上传失败）：

![添加子账户](/docs/s3/bitiful/04-sub-account.png)

2. 为子账户**授予读写权限**（读 + 写即可）：

![授予读写权限](/docs/s3/bitiful/05-grant-permissions.png)

3. 为该子账户**添加 Key**，保存 **Access Key ID** 与 **Secret Access Key**：

![添加 Key 1](/docs/s3/bitiful/06-add-key-1.png)

![添加 Key 2](/docs/s3/bitiful/07-add-key-2.png)

## 配置 CORS

Web 端直传需配置桶 CORS。在桶设置中添加规则，**来源 Origin** 至少包含：

```text
https://xiachuan.net
```

如有 `www` 子域，请一并添加 `https://www.xiachuan.net`。**操作 Methods** 勾选 `GET`、`PUT`、`POST`、`DELETE`、`HEAD`；**Allow-Headers** 建议 `*`；**Expose-Headers** 至少包含 `ETag`。

## 填写虾传设置

在虾传中填写缤纷云参数，有两种入口（二选一即可）：

1. **设置 → S3**：在全局设置中保存，登录同一账号的设备都会使用这份配置。
2. **S3 云端中转会话**：打开「S3 云端中转」会话，在会话内进入 **S3 设置** 填写；适合临时配置或只想在该会话中使用。

按缤纷云控制台信息填写各字段：

| 字段 | 说明 |
| --- | --- |
| Endpoint | **必须**为 `https://s3.bitiful.net`（含 `https://`，不可省略） |
| Region | 桶详情中的服务可用区 |
| Bucket | 桶名称 |
| Path-style 访问 | **关闭**（缤纷云使用虚拟托管域名） |
| Access Key ID | 子账户 Key 的 Access Key |
| Secret Access Key | 子账户 Key 的 Secret Key |

![虾传 S3 设置页（缤纷云示例）](/docs/s3/bitiful/08-shrimpsend-settings.png)

## 测试连接

保存后点击「测试连接」。若失败，请检查：

1. Endpoint 是否包含 `https://`。
2. Region、Bucket 是否与控制台一致。
3. 子账户是否有目标桶读写权限。
4. CORS 是否包含当前 Web Origin。
5. 子账户名称是否与桶名冲突。

## 相关链接

- [缤纷云官网](https://www.bitiful.com/)
- [缤纷云文档](https://docs.bitiful.com/)
