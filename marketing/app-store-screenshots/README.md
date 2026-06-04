# ShrimpSend — App Store / Google Play 截图

基于 [ParthJadhav/app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots) 模板，用真机 UI 截图生成英文营销素材。

## 快速开始

```bash
cd marketing/app-store-screenshots
npm install --legacy-peer-deps --cache .npm-cache

# 启动可视化编辑器
npm run dev          # → http://localhost:3000

# 批量导出（需 dev 服务器运行；使用系统 Chrome）
npm run export
```

## 目录

| 路径 | 说明 |
|------|------|
| `public/screenshots/apple/iphone/en/` | iOS 源 UI 截图 |
| `public/screenshots/android/phone/en/` | Android 源 UI 截图（与 iOS 同图） |
| `app-store-screenshots.json` | 编辑器状态（文案、布局、主题） |
| `output/*.zip` | 按设备导出的完整 zip |
| `output/upload/` | **可直接上传** 的整理版 PNG |

## 品牌

- 主题：`shrimpsend-emerald`（accent `#3D9B7E`，背景 `#F1F3F5`）
- 4 张 slide 文案见 `app-store-screenshots.json`

## 上传指引

### App Store Connect（English U.S.）

使用 `output/upload/app-store-6.5/`（**1284×2778**，6.5" Display）：

1. `01-connect.png` — All your devices, one list
2. `02-transfer.png` — Send files like a message
3. `03-s3-relay.png` — Cloud relay when LAN can't
4. `04-files.png` — Every transfer, organized

完整多尺寸包：`output/iphone/shrimpsend-ios-iphone-*.zip`（含 6.9" / 6.5" / 6.3" / 6.1"）

### Google Play Console

**Phone screenshots**（1080×1920）：`output/upload/google-play-phone/` 01→04

**Feature Graphic**（1024×500）：`output/upload/google-play/feature-graphic.png`

完整 zip：`output/android/` 与 `output/feature-graphic/`

### 发布前核对

- [ ] 缩略图下 headline 可读（约 160px 宽）
- [ ] ShrimpSend 品牌名正确
- [ ] 与 [`docs/store/google-play-play.md`](../../docs/store/google-play-play.md) 英文 Short description 一致
- [ ] 若屏内 UI 略糊，用 iPhone 6.1" 模拟器重截 1125×2436 替换 `public/screenshots/...` 后重新 `npm run export`

## 修改素材

1. 替换 `public/screenshots/...` 中的 PNG
2. `npm run dev` 打开编辑器微调文案/布局
3. `npm run export` 重新导出

## 依赖

- Node.js 18+
- Google Chrome（headless 导出，`PUPPETEER_EXECUTABLE_PATH` 可覆盖路径）
