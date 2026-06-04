# Google Play 商店说明（play 渠道 / 海外 ShrimpSend）

| 项 | 值 |
| --- | --- |
| 用途 | Google Play Console → 商店详情 → 简短说明 / 完整说明 |
| 渠道 | Android `play` flavor，`ANDROID_PLAY_DISTRIBUTION=true` |
| 构建 | 在 `app/` 下：`./scripts/package_android.sh --overseas --play`（产出 **arm64-v8a AAB**，用于 Play Console 上传） |
| 字符上限 | 简短说明 ≤ 80；完整说明 ≤ 4000 |
| 品牌 | 中英文均使用 **ShrimpSend** |
| 最后校对 | 2026-05-18 |

**链接（国际站）**

| 语言 | 官网 | 隐私政策 |
| --- | --- | --- |
| English | https://shrimpsend.com/en | https://shrimpsend.com/en/docs/privacy |
| 中文 | https://shrimpsend.com/zh | https://shrimpsend.com/zh/docs/privacy |

**Play 版勿写入商店文案的能力**：扫描已安装应用发送 APK、应用内安装 APK、应用内下载安装包更新（更新与订阅由 Google Play 提供）。

---

## English

### Short description（53 / 80）

```
Cross-device file transfer, straight to your devices.
```

### Full description（1,773 / 4,000）

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
Start free. Paid plans add more devices and hosted upload quota. Subscriptions are managed through Google Play and can be canceled anytime in Play Store → Account → Subscriptions.

Updates are delivered through Google Play.
Learn more: https://shrimpsend.com/en
Privacy: https://shrimpsend.com/en/docs/privacy
```

---

## 中文（简体）

### 简短说明（17 / 80）

```
跨设备文件传输，直达你的每台设备。
```

### 完整说明（712 / 4,000）

```
跨设备文件传输，直达你的每台设备。

ShrimpSend 把手机、电脑和浏览器放进同一套设备会话。文字、剪贴板、照片、视频、文件夹和大文件，都可以选中目标设备后直接发送；不用先上传生成公开链接，也不用把资料塞进聊天软件再翻找。

为什么选择 ShrimpSend
• 为自己的多台设备设计：手机、电脑、浏览器之间高频传送更顺手
• 局域网优先：同一 Wi-Fi 下优先走 LAN / WebRTC，适合照片、视频和大文件
• 大文件更安心：原生客户端之间支持断点续传，中断后不必从头重来
• 一条会话装下所有内容：文字、媒体、文档和大文件都按设备归位
• Web 随时加入：登录后可让浏览器成为你的临时接收端
• 可靠兜底：直连不可用或跨网络时，可使用托管存储或自建 S3 兼容存储

使用体验
打开 ShrimpSend，选择目标设备，然后发送。手机截图直达电脑，电脑视频发到桌面，浏览器里的文字同步到手机。能直连时优先走本地网络；跨网络或网络受限时，也有 S3 兜底路径。

局域网与登录
同一 Wi-Fi 下，原生客户端可通过 mDNS 免登录发现彼此。登录用于同步设备列表、让 Web 端加入会话，并在防火墙/NAT 等复杂网络下获得服务端辅助链路。

会员（可选）
可免费开始使用。付费方案可增加绑定设备数与托管上传额度。订阅通过 Google Play 管理，可随时在 Play 商店 → 账户 → 订阅 中取消。

应用更新由 Google Play 提供。
了解更多：https://shrimpsend.com/zh
隐私政策：https://shrimpsend.com/zh/docs/privacy
```

---

## 校对清单

- [x] 简短说明 EN（53）/ ZH（17）字符数 ≤ 80
- [x] 完整说明 EN（1773）/ ZH（712）字符数 ≤ 4000
- [x] 未出现「扫描已安装应用」「应用内安装 APK」「侧载更新」等 Play 版不支持表述
- [x] 品牌统一为 ShrimpSend
- [x] 隐私政策 URL 为国际站 `/en/docs/privacy` 与 `/zh/docs/privacy`（非 `/privacy` 根路径）
- [ ] 与 Play 截图 / Feature Graphic 英文卖点一致（发布前人工核对）

---

## Play Console 重新提交流程（审核修复后）

构建产物：

```bash
cd app && ./scripts/package_android.sh --overseas --play
# 产出：app/dist/<x.y.z.b>/Shrimpsend-android-intl-play-arm64-v8a-<x.y.z.b>.aab
```

上传前在 Play Console 完成：

1. **应用内容 → 敏感应用权限 → 所有文件访问权限**：若曾提交声明，**撤回/删除**（AAB 已移除 `MANAGE_EXTERNAL_STORAGE`）。
2. **数据安全**：确认未声明「所有文件访问」；存储类权限仅保留相册/媒体读取等实际用途。
3. **发布 → 正式版/测试版**：上传新 AAB（`versionCode` 须高于已拒版本）。
4. **Bundle 详情**：确认 **Memory page size** 显示支持 16 KB。
5. **政策状态**：在问题详情中按指引标记已修复并重新提交审核。

版本说明建议（中英文）：

- 移除不需要的「所有文件访问」权限；文件夹/保存路径改用系统目录选择器。
- 更新原生库以支持 16 KB 内存页面大小。
- Play 版继续不包含 APK 扫描/侧载安装能力。
