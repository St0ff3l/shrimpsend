# Cloudflare R2 详细配置

本指南帮助你在 Cloudflare **R2 对象存储**上创建 Bucket、API 令牌与 CORS，并在虾传设置页完成对接。

> R2 提供 S3 兼容 API，存储与出站流量价格通常低于传统对象存储，适合作为虾传广域网中转桶。

## 适用场景

- 希望低 egress 费用的 S3 兼容存储。
- 已有 Cloudflare 账号，自行管理 R2 Bucket 与密钥。

## 准备工作

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)。
2. 在左侧 **构建 → 存储和数据库 → R2 对象存储 → 概述** 进入 R2（首次使用需开通，按存储与 Class A/B 操作计费）。

![进入 R2 对象存储：构建 → 存储和数据库 → R2 对象存储 → 概述](/docs/s3/cloudflare-r2/01-nav-r2.png)

## 查看 S3 API 地址

在 R2 **概述** 页的 **帐户详情** 中可找到 S3 兼容访问信息：

- **帐户 ID**：部分场景下 Endpoint 会包含账户标识。
- **S3 API**：即虾传 **Endpoint**，形如 `https://<accountid>.r2.cloudflarestorage.com`，点击右侧复制按钮即可。

如需创建或管理密钥，可点击 **API 令牌 → 管理** 进入令牌页面。

![帐户详情：S3 API 地址与 API 令牌入口](/docs/s3/cloudflare-r2/02-account-s3-api.png)

## 创建 API 令牌

1. 进入 **R2 对象存储 → 管理 R2 API 令牌**（或从帐户详情 **API 令牌 → 管理** 进入）。
2. 个人使用推荐点击 **创建 User API 令牌**；生产环境可使用 Account API 令牌。
3. 权限选择 **对象读和写**，范围限定到目标 Bucket（或按需选择「所有存储桶」）。
4. 创建成功后保存 **Access Key ID** 与 **Secret Access Key**（Secret 仅显示一次）。

![创建 User API 令牌](/docs/s3/cloudflare-r2/03-create-api-token.png)

## 创建存储桶

1. 在 R2 **概述** 页点击 **+ 创建存储桶**。
2. 填写桶名称（全局唯一，创建后不可修改；示例：`xiachuantest`）。
3. **位置** 可保持 **自动**（系统选择就近区域）；**默认存储类** 选 **标准** 即可。
4. 桶默认为私有，点击 **创建存储桶** 完成。

![R2 概述页：创建存储桶入口](/docs/s3/cloudflare-r2/04-bucket-list.png)

![创建存储桶：名称与位置](/docs/s3/cloudflare-r2/05-create-bucket.png)

## 配置 CORS

浏览器直传必须配置桶 CORS：

1. 打开目标桶 → **设置** 选项卡。
2. 在左侧找到 **CORS 策略**，点击 **编辑**。
3. 将下方 JSON **整段复制粘贴** 到编辑器，保存。

![CORS 策略：设置 → 编辑](/docs/s3/cloudflare-r2/06-cors-settings.png)

```json
[
  {
    "AllowedOrigins": [
      "https://xiachuan.net",
      "https://www.xiachuan.net"
    ],
    "AllowedMethods": [
      "GET",
      "PUT",
      "POST",
      "DELETE",
      "HEAD"
    ],
    "AllowedHeaders": [
      "*"
    ],
    "ExposeHeaders": [
      "ETag",
      "Content-Length"
    ],
    "MaxAgeSeconds": 86400
  }
]
```

![CORS 策略 JSON 示例](/docs/s3/cloudflare-r2/07-cors-json.png)

## 填写虾传设置

在虾传中填写 R2 参数，有两种入口（二选一即可）：

1. **设置 → S3**：全局保存，同账号各设备共用。
2. **S3 云端中转会话**：在会话内打开 **S3 设置** 填写。

| 字段 | 说明 |
| --- | --- |
| Endpoint | 帐户详情中的 **S3 API** 地址，**必须**含 `https://` |
| Region | 填 `auto`（R2 S3 兼容 API 通用值） |
| Bucket | 刚创建的桶名 |
| Path-style 访问 | **开启**（R2 S3 API 通常需 Path-style） |
| Access Key ID | R2 API 令牌的 Access Key |
| Secret Access Key | R2 API 令牌的 Secret Key |

![虾传 S3 设置页](/docs/s3/bitiful/08-shrimpsend-settings.png)

## 测试连接

1. 点击 **测试连接**，应提示连接成功。
2. 在两台不同网络的设备间发送文件，确认走 S3 中转且无 CORS 报错。
3. 若失败，打开浏览器开发者工具 → Network，查看 PUT 请求是否被 CORS 拦截。

## 常见问题

**Region 填什么？**  
R2 填 `auto` 即可。

**403 或签名错误？**  
检查 API 令牌是否绑定正确 Bucket，Endpoint 是否与 S3 API 地址一致，Path-style 是否已开启。

**测试成功但上传失败？**  
多为 CORS Origin 未包含你实际打开 Web 的域名。

**与平台内置 S3 的区别？**  
内置 S3 由平台托管；本文为 **你自己的 R2 Bucket**。
