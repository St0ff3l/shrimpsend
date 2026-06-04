# Built-in S3 (International)

The international ShrimpSend deployment includes **platform-managed object storage**. No Endpoint, Bucket, or secret keys are required for wide-area transfers.

## When to use it

- You do not want to operate custom storage yet.
- Devices are on different networks and LAN / WebRTC direct paths fail.
- Files are temporary relay payloads, not long-term archive.

## How it works

Built-in S3 uses **Cloudflare R2** (`shrimpsendfiles` bucket by default).

- **Zero config** in Settings → S3 while in hosted mode.
- **Fallback path** after LAN / WebRTC attempts fail.
- **Membership quota** counted per UTC calendar month.
- **Up to ~30 days retention**; objects may be purged automatically.
- **Not a cloud drive**—relay only, not guaranteed backup.

![Hosted S3 mode in settings](/docs/s3/built-in/01-hosted-mode.png)

## Enable

1. Open **Settings → S3**.
2. Choose **Use built-in S3** (wording may vary) instead of disabled or custom mode.
3. Save—no Endpoint or keys needed.

To move payloads to your own bucket later, follow [S3 overview](/en/docs/s3/overview) and a provider guide in the sidebar.

## vs custom S3

| | Built-in | Custom |
| --- | --- | --- |
| Setup | None | Full config + CORS |
| Data | Platform R2 | Your storage |
| Quota | Membership monthly | Vendor billing |
| Retention | ~30 days platform policy | You manage |

## FAQ

**CORS for built-in?** No—platform maintains bucket CORS.

**Monthly usage?** See progress on the hosted S3 card in Settings.

**Switch back to custom?** Yes if you previously saved custom credentials; verify bucket and CORS still work.
