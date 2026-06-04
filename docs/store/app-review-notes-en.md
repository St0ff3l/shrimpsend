# App Store Review Notes（ShrimpSend intl）

Copy the text below into **App Store Connect → App Review Information → Notes** when submitting.

---

## Review Notes (English)

```
Demo account (required for Membership and In-App Purchases):
Email: 1204833748@qq.com
Password: [contact maintainer for demo credentials — see private ops store review notes]

Please sign in before testing Membership or subscriptions. Account-only features (Membership, My Devices, S3) are hidden in Settings until signed in.

In-App Purchases:
- Open Settings → Membership after signing in
- Subscriptions use Apple Sandbox; no pre-approval required
- "Restore Purchases" is available on the Membership screen

If camera or local network permission is requested, prompts match the app language (English or Simplified Chinese).

In-App Purchase product IDs (intl, must match App Store Connect + RevenueCat):
- shrimpsend_plus_monthly / shrimpsend_plus_yearly
- shrimpsend_pro_monthly / shrimpsend_pro_yearly
- shrimpsend_ultra_monthly / shrimpsend_ultra_yearly
RevenueCat webhook: https://api.shrimpsend.com/api/membership/revenuecat/webhook
```

---

## 审核回复模板（Guideline 逐项说明，可选）

在 Resolution Center 回复时可参考：

**2.3.10 — Metadata**
We removed all Android / Google Play references from the App Store description and in-app membership copy on iOS.

**Guideline 4 — Permissions**
All iOS usage description strings are now localized in English and Simplified Chinese via InfoPlist.strings.

**2.1 — Demo account**
The demo account credentials have been verified on production. Please sign in first; account features appear in Settings after login.

**2.1(b) — Membership / IAP**
We fixed an issue where unsigned-in users could open Membership and get redirected to login. Membership, My Devices, and S3 are now hidden until signed in. IAP has been tested in Sandbox with the demo account.
