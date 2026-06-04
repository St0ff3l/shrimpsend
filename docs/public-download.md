# 官网公开发布链接

官网下载按钮与客户端 **OTA 自动更新** 使用不同数据源：

| 用途 | 管理入口 | API |
|------|----------|-----|
| OTA（应用内更新） | 后台 → 版本管理 → 上传 APK/ZIP 至对象存储 | `GET /api/app/version`、`/api/app/desktop-update.json` |
| 官网公开下载 | 后台 → 版本管理 → **官网公开发布（外链）** | `GET /api/app/public-download` |

## 运营流程

1. 将安装包或商店页链接上传到网盘 / 商店（Google Play、App Store 等），获得 **https** 静态链接。
2. 打开 **管理后台 → 版本管理**，创建或编辑对应 `build`。
3. 在 **官网公开发布** 区域填写：
   - **大陆**：macOS / Windows 安装包、Android APK 网盘、iOS App Store。
   - **海外**：macOS / Windows、**Google Play**、**App Store**、可选 Android APK 网盘。
4. 点击列表中的 **设为官网**，将当前版本标记为 `web_published`（全局仅一条）。
5. 部署 Web 后，登录页/下载弹窗会从 API 读取链接；API 不可用时回退到 `web/src/data/client-downloads.json`。

## 注意事项

- 请勿把 OTA 用的 R2/COS **ZIP 直链**误填为官网 macOS/Windows 安装包（除非刻意如此）。
- 海外 Web 会单独展示 **Google Play** 与 **App Store** 按钮；未配置时 Play 使用默认包名链接兜底。
- 数据库迁移：执行 `backend/scripts/migration_app_version_public_download.sql`。
