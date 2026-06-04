# RustFS Setup Guide

Connect ShrimpSend to RustFS. See [RustFS docs](https://docs.rustfs.com/) for installation.

## Console

![Create bucket](/docs/s3/rustfs/04-create-bucket.png)

![Access keys](/docs/s3/rustfs/01-access-keys.png)

![Create key](/docs/s3/rustfs/02-create-key.png)

![Key created](/docs/s3/rustfs/03-key-created.png)

## CORS

```yaml
RUSTFS_CORS_ALLOWED_ORIGINS: https://shrimpsend.com,https://www.shrimpsend.com
```

![CORS env](/docs/s3/rustfs/06-cors-compose.png)

## ShrimpSend settings

S3 API Endpoint, Region `us-east-1`, Path-style **on**.

![ShrimpSend settings](/docs/s3/rustfs/05-shrimpsend-settings.png)

## Test connection

Save and run **Test connection**.
