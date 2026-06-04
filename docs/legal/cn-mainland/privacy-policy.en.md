# Privacy Policy (Mainland China Version)

**Effective date**: May 13, 2026  
**Last updated**: May 13, 2026

Operator: **Beijing Mingman Information Technology Co., Ltd.** ("we", "us", or "our")  
Contact email: **cmlanche@qq.com**

This Privacy Policy applies to "ShrimpSend", related clients (including mobile apps, desktop apps, HarmonyOS apps, and others), and the **Web app** that we provide under the service cluster deployed and operated in Mainland China (collectively, the "Product" or "Service"). **This version applies only when you choose to connect to Mainland China service nodes, for example `api.xiachuan.net` / `wss://ws.xiachuan.net`.**

> **Important notice**: This document is prepared based on the Product's current technical implementation and **does not constitute legal advice**. This English translation is for reference only. In case of inconsistency, the Chinese version shall prevail.

---

## 1. Information we process

### 1.1 Account and authentication

- **Email address**: used for registration, login, verification codes, and important notices.
- **Password**: stored as an encrypted digest; we cannot restore your plaintext password.
- **Nickname / display name** (if provided): used for display in device lists, conversation interfaces, and similar places.
- **Verification code**: used during registration or login; retained only for the short period necessary for verification.
- **Mobile phone number** (if we provide phone verification or you use it with separate consent): used to send SMS verification codes. SMS sending may be processed by providers such as **Tencent Cloud SMS**. See "Third-party services".

### 1.2 Device and terminal information

To synchronize messages and files across terminals, we process:

- **Device identifiers** (for example an app-generated `deviceId`), **platform type** (such as iOS, Android, Windows, macOS, Linux, Web, HarmonyOS), and **device name** (which you may edit).
- **Session version / login state information**: used for security verification and multi-device management.

### 1.3 Service usage and communication metadata

- **Realtime connection and subscription information**: WebSocket connections and channel subscriptions maintained through a **message middleware** layer (for example user-level channel subscriptions over WebSocket), used to deliver messages and transfer signaling.
- **Message and file metadata**: for example message type, timestamp, storage-related key names or object keys, file size, multipart upload task identifiers, and similar data. **For files transferred through "your own object storage", file contents are uploaded/downloaded directly through the storage provider you configure; we do not keep such file contents on our own servers as a long-term hosted cloud drive.** If you do not use your own storage, the actual technical path is subject to the Product's configuration.
- **LAN / direct transfer**: in scenarios such as "specified device", file data may be transferred between devices through your LAN, WebRTC, or similar channels. Under this path, content is usually **not persistently stored on our servers**, but connection and diagnostic metadata may still be generated to support discovery, handshake, and signaling.

### 1.4 Network and logs

For security, troubleshooting, and compliance, servers may record:

- **Access time, API path, error code, source IP**, and similar access logs, retained for a reasonable period subject to internal policies.
- Information related to **exceptions and security events**.

### 1.5 Membership and transactions (if you purchase membership)

- **Order number, payment status, membership tier, device limit, add-on package count**, and other information necessary for performance.
- When payment is completed through **Alipay** or **Apple in-app purchase (integrated through RevenueCat)**, payment institutions process transaction information according to their own rules. We only receive **necessary receipt fields** related to benefit fulfillment.

### 1.6 Product improvement and analytics

We may use a **third-party analytics service** to collect **de-identified or aggregated** usage information, such as app version, screen views, success/failure of certain actions, and **bucketed statistical dimensions** (for example file-size buckets or text-length buckets). **We do not report chat body text, complete file names, or plaintext identifiers of peer devices for analytics.**

---

## 2. System permissions and local capabilities

Different operating systems request authorization in the form of "permissions" or privacy-sensitive capabilities. The following descriptions reflect the current Product implementation and typical use cases. **If a specific version does not include a capability, the actual system prompt on your device shall prevail.**

### 2.1 Android (non-Google Play distribution, typical permissions)

| Permission or capability | Purpose |
|------------|----------|
| **Network access (INTERNET)** | Connect to APIs, realtime channels, object storage presigned URLs, and similar services. |
| **Camera (CAMERA)** | Scan QR codes for login and transfer-related scenarios. |
| **Storage / media read and write** | Select files, save received images/videos to albums, cache data, resume transfers, and similar uses. |
| **Read media images/videos/audio** | Read media that you actively select for sending. |
| **Wi-Fi state and changes, precise/approximate location, nearby Wi-Fi devices** | Used for **Smart Link / Wi-Fi Direct / LAN discovery and direct connection**; **not used for continuous geographic location tracking**. In nearby Wi-Fi permission scenarios that support `neverForLocation`, permissions are not used to infer precise location as required by the system. |
| **Query all installed apps (QUERY_ALL_PACKAGES)** | Certain builds may use this for **APK scanning/sending/installation** related capabilities, if provided by that version. |
| **Request package installation (REQUEST_INSTALL_PACKAGES)** | Install APKs with your consent, if provided by that version. |

**Google Play distribution variant**: To comply with app store policies, this variant may **not include** permissions such as "query all installed apps" or "request unknown app installation"; the corresponding functions may be **unavailable or removed** in the Play version.

Folder selection and custom save locations use the **system directory picker (SAF)**. Exporting to the system **Downloads** collection on Android 10+ uses **MediaStore**.

### 2.2 Android (Google Play distribution variant)

In versions installed through Google Play, **`QUERY_ALL_PACKAGES` and `REQUEST_INSTALL_PACKAGES` permissions are not included**. We do not request those permissions through that version.

### 2.3 iOS / iPadOS

| Purpose shown in system prompt | Capability |
|--------------------------|------|
| **Local network** | Discover and connect to devices on the LAN for file transfer; involves Bonjour services such as `_ultrasend._tcp`, `_wifi-direct._tcp` / `_wifi-direct._udp`, subject to actual system display. |
| **Camera** | Scan QR codes for login. |
| **Photos (read/write)** | Save received images/videos to albums; read media you choose for sending. |

If you use the **iOS share extension**, the system may pass content shared from other apps to the extension. We process it only to the extent necessary to complete the sharing and sending action you initiate.

### 2.4 macOS

| Purpose | Capability |
|----------|------|
| **Local network** | Discover LAN devices and perform LAN file transfer (Bonjour, such as `_ultrasend._tcp`). |
| **Screen recording / auxiliary capture capabilities** | Used for **screenshot and annotation** functions in the tray, consistent with the system `NSScreenCaptureUsageDescription`. |

### 2.5 Windows / Linux (desktop)

These usually rely on network and local file system access. Specific capabilities are subject to each distribution package and system prompt.

### 2.6 HarmonyOS

Typical declarations include **Internet**, **Wi-Fi information access**, and **camera** (for QR scanning and similar uses), supporting network connection, LAN-related capabilities, and scanning scenarios.

---

## 3. Cookies and local storage (Web)

When you use the **Web app**, we may use:

- **Browser local storage (such as localStorage)**: stores login tokens, language and service region preferences, and similar data.
- **Cookies necessary for security and sessions** (if applicable).

You may manage cookies and site data through browser settings. **After clearing them, you may need to log in again or choose preferences again**.

---

## 4. Third-party services and SDKs

To implement the Product, we may integrate or rely on the following types of third parties (**subject to the actual integrated version**):

| Type | Examples | Description |
|------|------|------|
| Email service | SendCloud and others | Send email verification codes or notification emails. |
| SMS service | Tencent Cloud SMS and others | Send SMS verification codes when phone verification is enabled. |
| Payment / in-app purchase | Alipay, Apple App Store, RevenueCat | Complete membership purchases and benefit verification. |
| Analytics | Third-party analytics service | Product usage statistics and improvement; specific providers and reporting endpoints are configured per deployment and are not listed in this document. |

We require third parties, through contracts or platform rules, to process information within the authorized scope and continuously evaluate their security capabilities. **Third parties have independent privacy policies, and we recommend that you read them as well.**

---

## 5. Legal bases for processing (summary)

Subject to applicable laws and regulations such as the Personal Information Protection Law of the People's Republic of China, we may process information based on:

- **Necessity for entering into or performing a contract** (providing the synchronization and transfer services you request);
- **Your consent** (for example optional features or marketing communications if separately consented to);
- **Compliance with legal obligations** (such as cooperating with regulatory requirements).

---

## 6. Sharing, transfer, and public disclosure

- We **do not sell** your personal information.
- Under the **minimum necessary** principle, we may share information necessary for performance with service providers.
- Where **required by law** or **to protect life, property safety**, and similar circumstances, we may disclose information to regulators or competent authorities in accordance with law.

---

## 7. Storage location and cross-border transfer

**Personal information under this Privacy Policy (Mainland China version) is, in principle, stored and processed within the territory of the People's Republic of China.** If cross-border transfer is involved due to the use of overseas third parties (for example certain cloud services or payment receipt paths), we will perform security assessment, standard contracts, certification, separate consent, or other obligations as required by law (where applicable), and explain the specific scenario to you.

---

## 8. Retention period

- **Account information**: retained during the existence of the account. After account cancellation, it will be deleted or anonymized within the period required by laws and regulations, unless extended retention is legally required.
- **Logs and orders**: retained for periods required by cybersecurity, accounting, tax, and other regulations.

---

## 9. Your rights

To the extent permitted by applicable law, you may exercise rights regarding personal information such as **access, copy, correction, supplementation, deletion, withdrawal of consent, restriction of processing, explanation**, and lawful **account cancellation**. You may contact us at **cmlanche@qq.com**; we will respond within the statutory period.

---

## 10. Protection of minors

If you are a minor, please read this Policy and use the Service under the guidance of your guardian. We do not actively market to children. If we discover that we have collected children's information without appropriate consent, we will delete it as soon as possible.

---

## 11. Updates to this Policy

We may revise this Policy from time to time. For material changes, we will notify you through in-app prompts, website announcements, emails, or other reasonable means. **If you continue to use the Service, you are deemed to have accepted the updated Policy** (except where renewed consent is required by law).

---

## 12. Contact us

If you have questions, complaints, or requests related to this Policy, please contact: **cmlanche@qq.com**.

---

**Footer statement**: Product functions continue to evolve. If this Policy is inconsistent with specific function descriptions, the updated Policy text shall prevail.
