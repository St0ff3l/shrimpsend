# Bitiful setup (Recommended)

[Bitiful](https://www.bitiful.com/) is ShrimpSend’s **top recommended** custom S3 provider: S3-compatible API, pay-as-you-go billing, and pricing that is often lower than major domestic clouds. See the official [price comparison](https://docs.bitiful.com/prices/compare).

## When to use

- You want cost-effective object storage with a stable S3-compatible service in China.
- You manage your own bucket and access keys on Bitiful.

## Create a bucket

1. Sign in to the [Bitiful console](https://console.bitiful.com/).
2. Create a new bucket. For security, use a **private** bucket.

![Create bucket step 1](/docs/s3/bitiful/01-create-bucket-1.png)

![Create bucket step 2](/docs/s3/bitiful/02-create-bucket-2.png)

## Endpoint and region

On the bucket details page, find the **service endpoint** and **availability zone**:

![Service endpoint and region](/docs/s3/bitiful/03-endpoint-region.png)

- **Endpoint** **must** be `https://s3.bitiful.net` — the `https://` prefix is **required**; do not omit it or use `http://`.
- **Region** is the availability zone code shown in the console.

## Create Access Key / Secret Key

1. **Add a sub-account** (**the sub-account name must not match the bucket name**, or uploads may fail):

![Add sub-account](/docs/s3/bitiful/04-sub-account.png)

2. Grant **read and write** permissions to the sub-account:

![Grant read/write permissions](/docs/s3/bitiful/05-grant-permissions.png)

3. **Create a key** for the sub-account and save the **Access Key ID** and **Secret Access Key**:

![Add key step 1](/docs/s3/bitiful/06-add-key-1.png)

![Add key step 2](/docs/s3/bitiful/07-add-key-2.png)

## Configure CORS

Browser uploads require bucket CORS. Add a rule with **Allowed Origins** including at least:

```text
https://xiachuan.net
```

Add `https://www.xiachuan.net` if you use the `www` subdomain. **Allowed Methods**: `GET`, `PUT`, `POST`, `DELETE`, `HEAD`. **AllowedHeaders**: `*` recommended. **ExposeHeaders**: at least `ETag`.

## ShrimpSend settings

Open S3 configuration from either entry point:

1. **Settings → S3** — saved globally for all devices signed into the same account.
2. **S3 cloud relay session** — open the **S3 cloud relay** chat and use **S3 settings** inside the session.

Fill in the fields from the Bitiful console:

| Field | Notes |
| --- | --- |
| Endpoint | **Must** be `https://s3.bitiful.net` (include `https://`; do not omit) |
| Region | Availability zone from bucket details |
| Bucket | Bucket name |
| Path-style access | **Off** (Bitiful uses virtual-hosted-style URLs) |
| Access Key ID | Sub-account key access key |
| Secret Access Key | Sub-account key secret |

![ShrimpSend S3 settings (Bitiful example)](/docs/s3/bitiful/08-shrimpsend-settings.png)

## Test connection

After saving, click **Test connection**. If it fails, check:

1. Endpoint includes `https://`.
2. Region and Bucket match the console.
3. Sub-account has read/write on the bucket.
4. CORS includes your web Origin.
5. Sub-account name does not conflict with the bucket name.

## Links

- [Bitiful](https://www.bitiful.com/)
- [Bitiful docs](https://docs.bitiful.com/)
