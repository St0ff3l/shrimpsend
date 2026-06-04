# Bitiful setup (Recommended)

[Bitiful](https://www.bitiful.com/) is ShrimpSend’s **top recommended** custom S3 provider: S3-compatible API, pay-as-you-go billing, and competitive pricing. See the official [price comparison](https://docs.bitiful.com/prices/compare).

## When to use

- You want cost-effective S3-compatible storage you control yourself.
- You are comfortable managing buckets and keys on Bitiful.

## Create a bucket

1. Sign in to the [Bitiful console](https://console.bitiful.com/).
2. Create a new **private** bucket.

![Create bucket step 1](/docs/s3/bitiful/01-create-bucket-1.png)

![Create bucket step 2](/docs/s3/bitiful/02-create-bucket-2.png)

## Endpoint and region

![Service endpoint and region](/docs/s3/bitiful/03-endpoint-region.png)

- **Endpoint** **must** be `https://s3.bitiful.net` — the `https://` prefix is **required**.
- **Region**: availability zone from bucket details

## Create Access Key / Secret Key

1. Add a sub-account (**name must not match the bucket name**):

![Add sub-account](/docs/s3/bitiful/04-sub-account.png)

2. Grant read/write permissions:

![Grant permissions](/docs/s3/bitiful/05-grant-permissions.png)

3. Create and save the key pair:

![Add key 1](/docs/s3/bitiful/06-add-key-1.png)

![Add key 2](/docs/s3/bitiful/07-add-key-2.png)

## Configure CORS

Allow at least:

```text
https://shrimpsend.com
```

Add `https://www.shrimpsend.com` if needed. Methods: `GET`, `PUT`, `POST`, `DELETE`, `HEAD`.

## ShrimpSend settings

Use either entry point:

1. **Settings → S3** — global config for all devices on the account.
2. **S3 cloud relay session** — open **S3 settings** inside the session.

| Field | Notes |
| --- | --- |
| Endpoint | **Must** be `https://s3.bitiful.net` (include `https://`) |
| Region | Availability zone |
| Bucket | Bucket name |
| Path-style access | **Off** |
| Access Key ID / Secret Access Key | Sub-account key |

![ShrimpSend S3 settings (Bitiful)](/docs/s3/bitiful/08-shrimpsend-settings.png)

## Test connection

Save and run **Test connection**. Verify CORS, Region, and sub-account permissions.

## Links

- [Bitiful](https://www.bitiful.com/)
- [Bitiful docs](https://docs.bitiful.com/)
