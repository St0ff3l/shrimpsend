# App Store 商店说明（iOS intl / ShrimpSend）

| 项 | 值 |
| --- | --- |
| 用途 | App Store Connect → App Information / Version → 描述、副标题、推广文本 |
| 渠道 | iOS intl 包，Bundle ID `dev.ultrasend.app` |
| 字符上限 | 副标题 ≤ 30；推广文本 ≤ 170；描述 ≤ 4000 |
| 品牌 | 中英文均使用 **ShrimpSend** |
| 最后校对 | 2026-05-26 |

**勿写入 iOS 商店文案**：Android、Google Play、Play Store、安卓、APK 安装等其它平台表述。

**链接（国际站）**

| 语言 | 官网 | 隐私政策 |
| --- | --- | --- |
| English | https://shrimpsend.com/en | https://shrimpsend.com/en/docs/privacy |
| 中文 | https://shrimpsend.com/zh | https://shrimpsend.com/zh/docs/privacy |

---

## English

### Subtitle（≤ 30）

```
Cross-device file transfer
```

### Promotional Text（≤ 170，可选）

```
Send files between your phone, computer, and browser like a message. LAN-first, with cloud relay when you need it.
```

### Description（≤ 4000）

```
Cross-device file transfer, straight to your devices.

ShrimpSend turns your phone, laptop, desktop, and browser into one device-to-device conversation. Drop in text, clipboard snippets, photos, videos, folders, or large files, choose where they should go, and keep moving. No public link to create. No chat thread to clean up. Just send once and reach the device you need.

WHY SHRIMPSEND
• Built for your own devices — move daily work between phone, computer, and browser
• LAN-first by design — use direct LAN / WebRTC paths on the same network when available
• Big-file friendly — native apps can resume interrupted transfers instead of starting over
• One flow for everything — text, media, documents, and large files live in the same device session
• Web when you need it — sign in to bring a browser into your device list
• Reliable fallback — use hosted storage or your own S3-compatible bucket when direct paths are not available

HOW IT FEELS
Open ShrimpSend, pick a target device, and send. Screenshots arrive on your laptop. A video lands on your desktop. A note from your browser shows up on your phone. Large files can prefer the local network, while cross-network delivery still has a fallback path.

LAN & SIGN-IN
On the same Wi-Fi, native apps can discover each other with mDNS without signing in. Sign in to sync devices, add web participation, and use server-assisted path setup for stricter firewall or NAT environments.

MEMBERSHIP (OPTIONAL)
Start free. Paid plans add more devices and hosted upload quota. Subscriptions are managed through the App Store and can be canceled anytime in Settings → Apple ID → Subscriptions.

Learn more: https://shrimpsend.com/en
Privacy: https://shrimpsend.com/en/docs/privacy
```

---

## 中文（简体）

### 副标题（≤ 30）

```
跨设备文件传输
```

### 推广文本（≤ 170，可选）

```
像发消息一样，在手机、电脑和浏览器之间传文件。局域网优先，需要时走云端中继。
```

### 描述（≤ 4000）

```
跨设备文件传输，直达你的每台设备。

ShrimpSend 把手机、电脑和浏览器放进同一套设备会话。文字、剪贴板、照片、视频、文件夹和大文件，都可以选中目标设备后直接发送；不用先上传生成公开链接，也不用把资料塞进聊天软件再翻找。

为什么选择 ShrimpSend
• 为自己的多台设备设计：手机、电脑、浏览器之间高频传送更顺手
• 局域网优先：同一 Wi-Fi 下优先走 LAN / WebRTC，适合照片、视频和大文件
• 大文件更安心：原生客户端之间支持断点续传，中断后不必从头重来
• 统一入口：文字、媒体、文档和大文件都在同一设备列表里完成
• 浏览器也可参与：登录后把网页端加入设备列表
• 可靠兜底：直连不可达时，可使用托管存储或自建 S3 兼容存储

使用体验
打开 ShrimpSend，选中目标设备即可发送。截图到电脑、视频到桌面、浏览器里的笔记到手机，都在同一流程里完成。

局域网与登录
同一 Wi-Fi 下，原生 App 可通过 mDNS 互相发现，无需登录。登录后可同步设备列表、加入网页端，并在复杂网络环境下使用服务端协助建连。

会员（可选）
免费起步。付费方案可扩展设备数量与托管上传配额。订阅通过 App Store 管理，可随时在「设置 → Apple ID → 订阅」中取消。

了解更多：https://shrimpsend.com/zh
隐私政策：https://shrimpsend.com/zh/docs/privacy
```

---

## ASC 上传前检查

- [ ] Description / Subtitle / Promotional Text / Keywords 无 Android / Google Play 字样
- [ ] What's New 无其它平台引用
- [ ] 6.5" / 6.7" 截图屏内 UI 无 Android 设备名或 Play 图标
- [ ] App Review Information 已填写有效 Demo 账号（见 [app-review-demo-account.md](./app-review-demo-account.md)）
- [ ] Review Notes 说明须先登录再测 Membership / IAP（见 [app-review-notes-en.md](./app-review-notes-en.md)）
