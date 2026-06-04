# Cloudflare R2 Setup Guide

Configure R2 bucket, API token, CORS, and ShrimpSend settings.

## Open R2

**Build → Storage & databases → R2 object storage → Overview** in the [Cloudflare Dashboard](https://dash.cloudflare.com/).

![Open R2](/docs/s3/cloudflare-r2/01-nav-r2.png)

## S3 API endpoint

Copy **S3 API** from **Account details**; use **API token → Manage** to create keys.

![Account details](/docs/s3/cloudflare-r2/02-account-s3-api.png)

## API token

**Create User API token** with **Object Read & Write** on your bucket.

![Create token](/docs/s3/cloudflare-r2/03-create-api-token.png)

## Create bucket

**+ Create bucket** on the Overview page.

![Bucket list](/docs/s3/cloudflare-r2/04-bucket-list.png)

![Create bucket](/docs/s3/cloudflare-r2/05-create-bucket.png)

## CORS

Bucket → **Settings → CORS policy → Edit**. Paste:

![CORS settings](/docs/s3/cloudflare-r2/06-cors-settings.png)

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

![CORS JSON](/docs/s3/cloudflare-r2/07-cors-json.png)

## ShrimpSend settings

**Settings → S3** or **S3 settings** in the cloud relay session. Endpoint = S3 API, Region = `auto`, Path-style **on**.

![ShrimpSend settings](/docs/s3/bitiful/08-shrimpsend-settings.png)

## Troubleshooting

403 → token scope and Path-style. Upload failures → CORS Origins.
