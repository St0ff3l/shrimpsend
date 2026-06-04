# Cloudflare R2 详细配置

本指南帮助你在 Cloudflare **R2 对象存储**上创建 Bucket、API 令牌与 CORS，并完成虾传对接。

## 适用场景

- 希望低 egress 费用的 S3 兼容存储。
- 国际版用户自建 R2 Bucket 作为广域网中转。

## 进入 R2

登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)，打开 **构建 → 存储和数据库 → R2 对象存储 → 概述**。

![进入 R2 对象存储](/docs/s3/cloudflare-r2/01-nav-r2.png)

## 查看 S3 API 地址

在 **帐户详情** 中复制 **S3 API** 作为 Endpoint；通过 **API 令牌 → 管理** 创建密钥。

![帐户详情：S3 API 地址](/docs/s3/cloudflare-r2/02-account-s3-api.png)

## 创建 API 令牌

点击 **创建 User API 令牌**，权限选 **对象读和写**，保存 Access Key 与 Secret Key。

![创建 User API 令牌](/docs/s3/cloudflare-r2/03-create-api-token.png)

## 创建存储桶

点击 **+ 创建存储桶**，填写名称后创建（默认私有）。

![创建存储桶入口](/docs/s3/cloudflare-r2/04-bucket-list.png)

![创建存储桶表单](/docs/s3/cloudflare-r2/05-create-bucket.png)

## 配置 CORS

桶 → **设置 → CORS 策略 → 编辑**，复制粘贴以下 JSON：

![CORS 策略编辑入口](/docs/s3/cloudflare-r2/06-cors-settings.png)

```json
[
  {
    "AllowedOrigins": [
      "https://shrimpsend.com",
      "https://www.shrimpsend.com"
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

![CORS JSON 配置](/docs/s3/cloudflare-r2/07-cors-json.png)

## 填写虾传设置

1. **设置 → S3**，或 **S3 云端中转会话** 内的 **S3 设置**。
2. Endpoint 填 S3 API 地址，Region 填 `auto`，Path-style **开启**。

![虾传 S3 设置页](/docs/s3/bitiful/08-shrimpsend-settings.png)

## 测试与排查

测试连接后实际传文件；403 检查令牌权限与 Path-style；上传失败优先查 CORS Origin。
