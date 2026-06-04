# Cloudflare R2 Setup Guide

Configure an R2 bucket, API token, CORS policy, and ShrimpSend settings.

## When to use R2

- S3-compatible storage with favorable egress pricing.
- You manage your own R2 bucket and keys on Cloudflare.

## Get started

1. Sign in to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Open **Build → Storage & databases → R2 object storage → Overview**.

![Open R2: Build → Storage & databases → R2 object storage → Overview](/docs/s3/cloudflare-r2/01-nav-r2.png)

## S3 API endpoint

On the R2 **Overview** page, under **Account details**:

- **Account ID** — may appear in the endpoint URL.
- **S3 API** — this is your ShrimpSend **Endpoint** (`https://<accountid>.r2.cloudflarestorage.com`). Use the copy button.

Click **API token → Manage** to create keys.

![Account details: S3 API and token entry](/docs/s3/cloudflare-r2/02-account-s3-api.png)

## Create an API token

1. Go to **R2 object storage → Manage R2 API tokens** (or **API token → Manage** from account details).
2. For personal use, click **Create User API token**.
3. Grant **Object Read & Write** scoped to your bucket.
4. Save **Access Key ID** and **Secret Access Key** (secret shown once).

![Create User API token](/docs/s3/cloudflare-r2/03-create-api-token.png)

## Create a bucket

1. On R2 **Overview**, click **+ Create bucket**.
2. Enter a globally unique name.
3. Keep **Automatic** location and **Standard** storage class unless you have other needs.
4. Click **Create bucket** (buckets are private by default).

![Create bucket entry](/docs/s3/cloudflare-r2/04-bucket-list.png)

![Create bucket form](/docs/s3/cloudflare-r2/05-create-bucket.png)

## Configure CORS

Browser uploads require CORS:

1. Open the bucket → **Settings** tab.
2. Select **CORS policy** → **Edit**.
3. Paste the JSON below and save.

![CORS policy: Settings → Edit](/docs/s3/cloudflare-r2/06-cors-settings.png)

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

![CORS JSON editor](/docs/s3/cloudflare-r2/07-cors-json.png)

## ShrimpSend settings

Open S3 configuration from either entry point:

1. **Settings → S3** — global config for all devices on the account.
2. **S3 cloud relay session** — use **S3 settings** inside the session.

| Field | Notes |
| --- | --- |
| Endpoint | **S3 API** from account details; must include `https://` |
| Region | `auto` |
| Bucket | Your bucket name |
| Path-style access | **On** (usually required for R2 S3 API) |
| Access Key ID | R2 token access key |
| Secret Access Key | R2 token secret |

![ShrimpSend S3 settings](/docs/s3/bitiful/08-shrimpsend-settings.png)

## Test connection

Run **Test connection**, then send a file across networks. Check DevTools if uploads fail with CORS errors.

## FAQ

**Region?** Use `auto`.

**403 / signature errors?** Verify token scope, endpoint, and Path-style.

**Built-in S3 vs your R2?** Built-in is platform-hosted; this guide is for **your own R2 bucket**.
