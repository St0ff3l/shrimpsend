# RustFS Setup Guide

Connect ShrimpSend to an existing [RustFS](https://github.com/rustfs/rustfs) instance. For RustFS installation, see the [official docs](https://docs.rustfs.com/).

## RustFS console

### Bucket

![Create bucket](/docs/s3/rustfs/04-create-bucket.png)

### Access keys

![Access keys](/docs/s3/rustfs/01-access-keys.png)

![Create key](/docs/s3/rustfs/02-create-key.png)

![Key created](/docs/s3/rustfs/03-key-created.png)

### CORS

Add to Docker Compose `environment`:

```yaml
RUSTFS_CORS_ALLOWED_ORIGINS: https://xiachuan.net,https://www.xiachuan.net
```

Comma-separated Origins, no spaces. Restart the container after changes.

![CORS environment variable](/docs/s3/rustfs/06-cors-compose.png)

## ShrimpSend settings

**Settings → S3** or **S3 settings** in the cloud relay session.

| Field | Notes |
| --- | --- |
| Endpoint | Your RustFS **S3 API** URL (must include `http://` or `https://`) |
| Region | `us-east-1` |
| Bucket | e.g. `test` |
| Path-style access | **On** |
| Keys | From RustFS console |

> Keep **Path-style access** enabled (see screenshot).

![ShrimpSend settings](/docs/s3/rustfs/05-shrimpsend-settings.png)

## Test connection

Save and run **Test connection**, then send a file. Verify Endpoint, Bucket, keys, Path-style, and CORS.

## FAQ

**Small files work but uploads fail at ~50MB+?**

When RustFS runs on your server behind **Nginx** (or another reverse proxy) for the S3 API, a common cause is the proxy **body size limit**. Default `client_max_body_size` is often `1m`; larger uploads may return `413 Request Entity Too Large`.

Raise the limit on the location that proxies to RustFS, for example:

```nginx
client_max_body_size 1024m;
```

Reload Nginx after changes. For very large files, you may also need higher `proxy_read_timeout` / `proxy_send_timeout`.

This is a **reverse-proxy** setting, not a ShrimpSend client limit.
