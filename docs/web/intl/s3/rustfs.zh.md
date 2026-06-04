# RustFS 详细配置

在 RustFS 上准备好桶与密钥后，按下列步骤在虾传中对接。RustFS 安装请参阅 [官方文档](https://docs.rustfs.com/)。

## 控制台准备

![创建存储桶](/docs/s3/rustfs/04-create-bucket.png)

![访问密钥](/docs/s3/rustfs/01-access-keys.png)

![创建密钥](/docs/s3/rustfs/02-create-key.png)

![密钥已创建](/docs/s3/rustfs/03-key-created.png)

## CORS

Docker / Compose 的 `environment` 增加：

```yaml
RUSTFS_CORS_ALLOWED_ORIGINS: https://shrimpsend.com,https://www.shrimpsend.com
```

![CORS 环境变量](/docs/s3/rustfs/06-cors-compose.png)

## 填写虾传设置

| 字段 | 示例 |
| --- | --- |
| Endpoint | RustFS S3 API 地址（含协议） |
| Region | `us-east-1` |
| Bucket | `test` |
| Path-style 访问 | **开启** |

> **Path-style 访问** 请保持开启。

![虾传 S3 设置](/docs/s3/rustfs/05-shrimpsend-settings.png)

## 测试连接

保存后点击 **测试连接** 并实际上传验证。
