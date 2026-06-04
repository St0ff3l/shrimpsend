# Tencent COS Setup Guide

Step-by-step setup for **Tencent Cloud Object Storage (COS)** and ShrimpSend.

> In the Tencent Cloud console, search **「对象存储」** (Object Storage)—that product is COS.

## When to use Tencent COS

- Users or infrastructure are primarily in mainland China.
- You want payloads stored on Tencent Cloud.

## Prerequisites

1. Sign in to the [Tencent Cloud console](https://console.cloud.tencent.com/).
2. Search for **Object Storage** and enable COS.

## Create a bucket

1. **Object Storage → Bucket List → Create Bucket**.
2. Choose a globally unique bucket name (cannot be changed later).
3. Select a **region** (see next section—it drives Endpoint and Region).
4. Set **Access permission** to **Private read/write** (recommended; access via keys and presigned URLs).

![Create bucket: private read/write](/docs/s3/tencent-cos/01-create-bucket-private.png)

## Region, Endpoint, and Region field

The bucket **region** determines the segment in the S3-compatible Endpoint and must match ShrimpSend’s **Region** field.

Example for **Guangzhou**:

- Endpoint: `https://cos.ap-guangzhou.myqcloud.com`
- Region: `ap-guangzhou`

The code between `cos.` and `.myqcloud.com` (e.g. **`ap-guangzhou`**) is the region identifier; it differs per city/zone.

![Select object storage region (Guangzhou example)](/docs/s3/tencent-cos/02-select-region.png)

| Console region | Endpoint example | ShrimpSend Region |
| --- | --- | --- |
| Guangzhou | `https://cos.ap-guangzhou.myqcloud.com` | `ap-guangzhou` |
| Shanghai | `https://cos.ap-shanghai.myqcloud.com` | `ap-shanghai` |
| Beijing | `https://cos.ap-beijing.myqcloud.com` | `ap-beijing` |

Use the full bucket name for **Bucket** (often includes APPID suffix, e.g. `my-bucket-1314690352`).

## Create API keys

Create keys at [API Key Management](https://console.cloud.tencent.com/cam/capi):

1. Open [https://console.cloud.tencent.com/cam/capi](https://console.cloud.tencent.com/cam/capi).
2. Create a key pair; you receive **SecretId** and **SecretKey**.
3. Mapping to ShrimpSend:
   - **SecretId** → **Access Key ID**
   - **SecretKey** → **Secret Access Key**

![API key management: SecretId example](/docs/s3/tencent-cos/03-cam-api-key.png)

> Prefer a sub-account key scoped to one bucket; avoid root account keys.

## Configure CORS

Bucket → **Security → Cross-origin CORS → Add rule**. Follow the screenshot:

![CORS settings: Origin and Methods example](/docs/s3/tencent-cos/05-cors-rule.png)

- **Origin**: `https://xiachuan.net` (+ `https://www.xiachuan.net` if needed)
- **Methods**: **PUT, GET, POST, DELETE, HEAD**
- **Allow-Headers**: `*`
- **Expose-Headers**: `ETag` (optionally `Content-Length`, `x-cos-request-id`)

## ShrimpSend settings

| Field | Example |
| --- | --- |
| Endpoint | `https://cos.ap-guangzhou.myqcloud.com` |
| Region | `ap-guangzhou` |
| Bucket | full name with APPID |
| Path-style | **Off** |
| Access Key ID | SecretId |
| Secret Access Key | SecretKey |

![Final ShrimpSend S3 settings (Tencent COS)](/docs/s3/tencent-cos/04-shrimpsend-settings.png)

## Test & FAQ

Use **Test connection**, then verify cross-network upload. **Region** must match the Endpoint region code (e.g. `ap-guangzhou`), not the Chinese city name.
