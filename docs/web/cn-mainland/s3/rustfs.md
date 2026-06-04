# RustFS 详细配置

[RustFS](https://github.com/rustfs/rustfs) 是 S3 兼容对象存储。本文说明在 RustFS 上准备好桶与密钥后，如何在虾传中完成对接。

> RustFS 的安装与运维请参阅 [RustFS 官方文档](https://docs.rustfs.com/)。

## 适用场景

- 已有可访问的 RustFS 实例，用于虾传广域网文件中转。

## 在 RustFS 控制台准备

### 创建存储桶

1. 登录 RustFS 控制台 → **对象浏览**。
2. 点击 **创建存储桶**，输入桶名（如 `test`），保持私有即可。

![创建存储桶](/docs/s3/rustfs/04-create-bucket.png)

### 创建访问密钥

1. **访问密钥** → **+ 添加访问密钥**。

![访问密钥列表](/docs/s3/rustfs/01-access-keys.png)

2. 填写信息后 **提交**。

![创建密钥](/docs/s3/rustfs/02-create-key.png)

3. **立即复制或导出** Access Key 与 Secret Key。

![新的访问密钥已创建](/docs/s3/rustfs/03-key-created.png)

### 配置 CORS

Web 端直传需在 RustFS 服务上允许虾传 Web 的 Origin。若使用 Docker / Compose 部署，在 `environment` 下增加：

```yaml
RUSTFS_CORS_ALLOWED_ORIGINS: https://xiachuan.net,https://www.xiachuan.net
```

多个 Origin 用英文逗号分隔，不要加空格。修改后重启 RustFS 容器生效。

![Compose 环境变量：RUSTFS_CORS_ALLOWED_ORIGINS](/docs/s3/rustfs/06-cors-compose.png)

YAML 片段示例：

```yaml
services:
  rustfs:
    environment:
      RUSTFS_ACCESS_KEY: ${RUSTFS_ACCESS_KEY}
      RUSTFS_SECRET_KEY: ${RUSTFS_SECRET_KEY}
      RUSTFS_CONSOLE_ENABLE: ${RUSTFS_CONSOLE_ENABLE}
      RUSTFS_CORS_ALLOWED_ORIGINS: https://xiachuan.net,https://www.xiachuan.net
```

## 填写虾传设置

入口：**设置 → S3**，或 **S3 云端中转会话** 内的 **S3 设置**。

从 RustFS 侧获取 **S3 API 地址**（不是 Web 控制台地址），填入虾传 **Endpoint**：

| 字段 | 说明 / 示例 |
| --- | --- |
| Endpoint | `https://rustfsapi.example.com`（**必须**含 `https://` 或 `http://`） |
| Region | `us-east-1` |
| Bucket | `test`（与控制台桶名一致） |
| Path-style 访问 | **开启**（自建 S3 对接虾传时需勾选） |
| Access Key ID | 访问密钥 |
| Secret Access Key | 密钥 |

> **特别注意：** **Path-style 访问** 开关请保持开启（见下图）。

![虾传 S3 设置页（RustFS 示例）](/docs/s3/rustfs/05-shrimpsend-settings.png)

## 测试连接

保存后点击 **测试连接**，再实际传文件验证。若失败，请检查 Endpoint、Bucket、密钥、Path-style 与 CORS Origin 是否与当前 Web 地址一致。

## 常见问题

**小文件正常，50MB 以上大文件上传失败？**

若 RustFS 部署在服务端且前面有 **Nginx**（或其他反向代理）转发 S3 API，小文件能成功、大文件失败，常见原因是代理的**请求体大小限制**。Nginx 默认 `client_max_body_size`  often 为 `1m`，超过即返回 `413 Request Entity Too Large`，浏览器侧表现为上传中断或失败。

在代理 RustFS S3 API 的 `server` / `location` 中调大限制，例如：

```nginx
client_max_body_size 1024m;
```

修改后重载 Nginx（`nginx -s reload`）。若仍有个别超大文件超时，可酌情增加 `proxy_read_timeout`、`proxy_send_timeout` 等。

> 此限制来自**反向代理配置**，与虾传客户端无关；直连 RustFS 端口（不经过 Nginx）时通常不受此项影响。

## 相关链接

- [RustFS 官方文档](https://docs.rustfs.com/)
