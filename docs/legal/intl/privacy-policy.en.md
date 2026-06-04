# Privacy Policy (International / ShrimpSend)

**Effective date:** May 13, 2026  
**Last updated:** May 13, 2026

Controller / Operator: **CryoNova Limited** (“**we**”, “**us**”)  
Contact: **wementio@gmail.com**

This Privacy Policy applies to **ShrimpSend** and related clients (mobile, desktop, HarmonyOS, etc.) and the **Web app** when you use our **international service cluster** (for example `https://api.shrimpsend.com` and `wss://ws.shrimpsend.com`).  

> This document reflects the product’s current technical design and is **not legal advice**.

---

## 1. Information we process

### 1.1 Account & authentication

- **Email address** for registration, login, verification codes, and service communications.  
- **Password** stored as a salted hash (we cannot read your plaintext password).  
- **Display name / username** (optional) for UI (device lists, chat headers, etc.).  
- **Verification codes** for registration/login flows (kept only as long as needed to verify).  
- **Phone number** if we offer phone verification and you opt in; SMS may be sent via providers such as **Tencent Cloud SMS** (see Third parties).

### 1.2 Devices

- **Device identifier** (app-generated `deviceId`), **platform** (iOS, Android, Windows, macOS, Linux, Web, HarmonyOS, etc.), and **device name** (editable).  
- **Session / security metadata** required to authenticate devices and prevent abuse.

### 1.3 Service usage & message/file metadata

- **Realtime connectivity & subscriptions** maintained through a **message middleware** layer (for example user-level channel subscriptions over WebSocket) to deliver messages and signaling.  
- **Metadata** about messages and transfers: types, timestamps, storage keys/object keys, sizes, multipart upload identifiers, etc.  
- **Bring-your-own (BYO) S3-compatible storage:** file **contents** are uploaded/downloaded using **presigned URLs** toward **your configured cloud provider**. We do not use our hosted bucket for those transfers.  
- **Platform-hosted storage (international deployments):** if you use our **hosted object storage** (e.g., **Cloudflare R2**), we act as a processor/host for encrypted objects and related metadata needed to operate the feature. **Monthly upload metering** applies (see Section 6).  
- **LAN / direct transfers:** payloads may move device-to-device (HTTP LAN stack, **WebRTC** with signaling through our servers). Content is generally **not persistently stored on our servers** for those paths, but signaling, connection diagnostics, and security logs may exist.

### 1.4 Networking & logs

We may collect **limited server logs** (timestamps, endpoints, status codes, coarse IP data) for security, abuse prevention, and reliability.

### 1.5 Membership & billing

If you purchase a subscription, we process **tier, billing period, device limits, hosted upload quota status**, **order references**, and payment-channel identifiers. Payments are processed by **Apple**, **Google Play**, and/or **Stripe**; we receive **transaction receipts** needed to grant entitlements. **RevenueCat** may be used to validate in-app purchases and synchronize subscription state.

### 1.6 Analytics

We may use a **third-party analytics service** to collect **de-identified or aggregated** usage information (app version, screen views, coarse success/failure signals, size/length buckets). **We do not intentionally upload message bodies, full filenames, or peer device identifiers** for analytics.

---

## 2. Permissions & on-device capabilities

The following maps **typical** OS disclosures to product features. **What you see on-device controls.**

### 2.1 Android (non–Google Play builds)

| Permission / capability | Purpose |
|-------------------------|---------|
| **INTERNET** | API calls, realtime connections, presigned storage URLs. |
| **CAMERA** | QR login and related flows. |
| **Storage / media read & write** | Picking files, saving received media, caches, resume. |
| **Wi‑Fi / location / nearby Wi‑Fi** | **Smart Link / Wi‑Fi Direct / discovery**; **not** for continuous user tracking. |
| **QUERY_ALL_PACKAGES / REQUEST_INSTALL_PACKAGES** | **APK scan/send/install** features where offered **outside** Play distribution. |

### 2.2 Android (Google Play flavor)

The Play flavor **removes** `QUERY_ALL_PACKAGES` and `REQUEST_INSTALL_PACKAGES`; we **do not** request those capabilities in that distribution.

Folder selection and custom save locations use the **system directory picker (Storage Access Framework, SAF)**. Exporting received files to the system **Downloads** collection uses **MediaStore** on Android 10+ and does not require broad storage access.

| Permission / capability | Purpose (Play builds) |
|-------------------------|------------------------|
| **INTERNET** | API calls, realtime connections, presigned storage URLs. |
| **CAMERA** | QR login and related flows. |
| **READ_MEDIA_*** / legacy storage (API ≤ 32) | Picking media and saving to the photo library. |
| **Wi‑Fi / location / nearby Wi‑Fi** | **Smart Link / Wi‑Fi Direct / discovery**; **not** for continuous user tracking. |

### 2.3 iOS / iPadOS

- **Local Network / Bonjour** (e.g., `_ultrasend._tcp`, `_wifi-direct._tcp` / `_wifi-direct._udp`) for LAN discovery and transfers.  
- **Camera** for QR login.  
- **Photo Library (read/add)** to save received media and to send media you select.  
- **Share Extension** (if used): processes content you share into the app **only** to complete your requested action.

### 2.4 macOS

- **Local Network / Bonjour** for LAN transfers.  
- **Screen capture** (as described in `NSScreenCaptureUsageDescription`) for **tray screenshot & annotation** features.

### 2.5 Windows / Linux

Network and filesystem access as required by the desktop clients; prompts depend on packaging.

### 2.6 HarmonyOS

Typical declarations include **Internet**, **Wi‑Fi info**, and **Camera** for connectivity and scanning.

---

## 3. Cookies & local storage (Web)

We may use **localStorage** (tokens, locale/region preferences) and **strictly necessary cookies** where applicable. Clearing site data may log you out.

---

## 4. Third parties & SDKs

Examples (actual vendors may evolve): **SendCloud** (email), **Tencent Cloud SMS** (if SMS enabled), **Apple App Store**, **Google Play Billing**, **Stripe**, **RevenueCat**, **third-party analytics** (usage statistics), **Cloudflare R2** (hosted storage), **S3-compatible endpoints** you configure (your processor relationship with that vendor).

Third parties have their own policies; please read them.

---

## 5. Legal bases (summary)

Depending on jurisdiction, we rely on **contract necessity**, **legitimate interests** (security, product improvement balanced against your rights), and **consent** where required.

---

## 6. Hosted upload quota (international only)

For the international deployment, if you use **hosted** object storage provided by us, **uploaded bytes are metered per UTC calendar month** and subject to tier limits, including:

| Tier | Device limit | Hosted upload quota (per UTC month) |
|------|--------------|----------------------------------------|
| **FREE** | 3 | **1 GiB** |
| **PLUS** | 10 | **80 GiB** |
| **PRO** | 20 | **250 GiB** |
| **ULTRA** | 50 | **800 GiB** |

Download and non-hosted paths may follow different rules; metering logic is enforced server-side.

Hosted object storage is a file-transfer relay, not a long-term cloud drive. Unless otherwise stated on the product page, hosted objects are generally retained for up to **30 days** after upload and may then be deleted automatically. Deletion of the related message or file, account termination, violations, security or abuse risks, or legal requirements may also lead to earlier deletion or restricted access.

---

## 7. International transfers

We may process data in **jurisdictions where we or our subprocessors maintain facilities (which may include the United States, Hong Kong SAR, and other regions)** and use providers in the **United States** and other regions. Where required, we implement appropriate safeguards (e.g., **Standard Contractual Clauses**) and provide notices/consent flows.

---

## 8. Retention

We retain data as long as needed to provide the service and meet legal obligations, then delete or anonymize it consistent with our retention schedule. Hosted transfer objects in the international deployment follow the temporary retention rule described above; account, order, billing, risk-control, security logs, and necessary metadata may be retained longer where required by law or service security needs.

---

## 9. Your rights

Depending on your location, you may have rights to **access, rectify, erase, restrict, port**, or **object** to certain processing, and to **withdraw consent** where processing is consent-based. Contact **wementio@gmail.com** to exercise rights. You may also lodge a complaint with your local supervisory authority.

---

## 10. Children

The service is not directed to children. If you believe we collected data from a child without appropriate consent, contact us and we will take appropriate steps.

---

## 11. Changes

We may update this policy and notify you as required by law (e.g., in-app notice or email for material changes).

---

## 12. Contact

**wementio@gmail.com**

---

_End of document_
