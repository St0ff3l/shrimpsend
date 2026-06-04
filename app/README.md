# app

A new Flutter project.

## OpenPanel（客户端统计）

使用仓库内补丁包 [`packages/openpanel_flutter`](packages/openpanel_flutter)（上游 0.3.0 + **HTTP `User-Agent` 仅 ASCII**，避免中文应用名导致 Dio 报错）。

生产环境下按 **`Env.prodServiceRegion`** 选择面板。**Client id / ingest URL / secret** 放在 gitignored `lib/config/openpanel_env.secrets.dart`（从 `openpanel_env.secrets.example.dart` 复制，或官方打包机从 ops 仓 sync）。可用 `--dart-define=OP_*` 覆盖。

RevenueCat 公钥与生产 API/WS URL 见 gitignored `lib/config/env.secrets.dart`（从 `env.secrets.example.dart` 复制，或 ops 仓 sync）。构建脚本支持 `RC_*`、`API_URL_PROD_*` 环境变量（见 `scripts/dart-define-env-secrets.sh`）。

```bash
cp lib/config/openpanel_env.secrets.example.dart lib/config/openpanel_env.secrets.dart
cp lib/config/env.secrets.example.dart lib/config/env.secrets.dart
# 或: ../../scripts/setup-local-config.sh
# 官方打包: ops/scripts/sync-to-build-machine.sh
```

| `dart-define` | 说明 |
| --- | --- |
| `OP_CN_APP_CLIENT_ID` | 国内 App client id |
| `OP_CN_APP_CLIENT_SECRET` | 国内 App secret（或 secrets.dart） |
| `OP_CN_API_BASE` | 国内 ingest 根 URL |
| `OP_INTL_APP_CLIENT_ID` | 海外 App client id |
| `OP_INTL_APP_CLIENT_SECRET` | 海外 App secret（或 secrets.dart） |
| `OP_INTL_API_BASE` | 海外 ingest 根 URL |

### 自定义事件（与 Web 同名 `snake_case`）

封装：`lib/services/analytics/analytics.dart`（`Analytics.track`）、事件名常量 `lib/services/analytics/analytics_events.dart`。不上报消息正文、文件名、对端设备明文 id；体积/长度用 bucket。Screen 仍由 OpenPanel 路由/observer 上报，此处不重复 `screen_view`。

| 事件名 | 含义 | 常见属性（节选） |
| --- | --- | --- |
| `locale_gate_completed` | 语言/地区门禁完成 | `result` |
| `login_submit` | 密码/验证码登录提交结果 | `result`、`auth_mode` |
| `register_submit` | 注册提交结果 | `result` |
| `login_code_submit` | 验证码登录提交 | `result` |
| `verification_code_send` | 发送验证码 | `channel`、`result` |
| `qr_login_outcome` | 扫码登录结果 | `result` |
| `logout` | 退出登录 | — |
| `device_remove` | 移除设备 | `result` |
| `send_mode_changed` | 发送模式切换 | `mode` |
| `chat_session_open` | 选中一条会话线程（含 S3 云线程） | `session_type`：`peer` / `s3` |
| `chat_text_send` / `chat_text_retry` | 文本消息发送/重试 | `result`、`length_bucket` 等 |
| `attachment_pick` | 选择附件 | `kind`、`count` |
| `file_send_intent` / `file_send_outcome` / `file_send_retry` / `file_send_cancel` | 文件传输意图/结果/重试/取消 | `size_bucket`、`result` 等 |
| `message_search` | 消息搜索 | `result`、`result_count_bucket` |
| `file_preview_open` / `file_save_to_gallery` | 文件预览/保存到相册 | `size_bucket` 等 |
| `membership_screen_view` / `membership_purchase_start` / `membership_purchase_outcome` | 会员页与购买漏斗 | `tier`、`result` 等 |
| `setting_changed` | 通用设置变更 | `key`、`result` |
| `s3_settings_save` | S3 配置保存 | `result` |
| `app_update_install_clicked` | 应用更新安装点击 | — |
| `share_into_app_received` | 系统分享进应用 | `mime_bucket` 等 |
| `offline_mode_enter` | 进入离线模式 | — |

**验收建议**：各环境各走一遍登录成功/失败、会员页、设置保存；在 OpenPanel 中核对事件与属性；断网或未初始化 SDK 时不应抛错或白屏。

## 外部分享到虾传（Android / iOS）

架构见 [`lib/services/share/`](lib/services/share/) 与 [`lib/services/share_receive_service.dart`](lib/services/share_receive_service.dart)。

| 组件 | 平台 | 职责 |
| --- | --- | --- |
| [fl_shared_link](https://pub.dev/packages/fl_shared_link) | Android + iOS | **主通道**：Android 单文件/社媒（微信/QQ）；iOS `openUrl` / Universal Link / 文档打开 |
| ShareIntentBridge | Android | **仅 `SEND_MULTIPLE`**：多 URI → attachments，汇入闪电藤式 payload 路由 |
| flutter_sharing_intent + Share Extension | iOS | **系统分享面板** → attachments → payload（iOS 恒 accept） |
| ShareInboundHub | Dart | 闪电藤路由：`Platform.isIOS \|\| attachments.length > 1` 才 ingest payload |

**Android**

- [`SharedLauncherActivity`](android/app/src/main/kotlin/dev/ultrasend/app/SharedLauncherActivity.kt) 在 [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) 声明 `SEND` / `SEND_MULTIPLE` / `VIEW`，转发到 `MainActivity`，避免覆盖 QQ/微信任务栈。
- 单文件 `SEND` / `VIEW` → `fl_shared_link.getRealFilePathWithAndroid`（不走 Bridge）。
- 多文件 `SEND_MULTIPLE` → ShareIntentBridge → `ShareInboundHub.handlePayload`。
- **请勿**在 Android 再订阅 `FlutterSharingIntent`，避免与 `fl_shared_link` 重复处理。

**iOS**

- 系统分享面板：Share Extension + `flutter_sharing_intent`（vendored [`packages/flutter_sharing_intent`](packages/flutter_sharing_intent/)）。
- 「用其他应用打开」/ 外链：`fl_shared_link`（`Info.plist` 已配 `CFBundleDocumentTypes`）。
- `SharingMedia-*` scheme 仍由 Share Extension handoff，fl_shared_link 侧会跳过以免重复 ingest。

**验收建议**

- Android：微信/QQ 单文件；相册多选；冷/热启动；连续分享无重复。
- iOS：分享面板 1 张/多张图；Files 用虾传打开（fl_shared_link）；待发文件箱正常。

## Android 构建（product flavor）

`android/app/build.gradle.kts` 定义了 `direct` / `play` 两个 flavor。推荐用脚本或显式传入 `--flavor direct` / `--flavor play`（例如 `flutter run -d <device> --flavor direct`），以免歧义。Google Play（`play`）商店简短说明与完整说明文案见 [`docs/store/google-play-play.md`](../docs/store/google-play-play.md)。未传 `--flavor` 时，Gradle 会在 `assembleDebug` / `assembleProfile` / `assembleRelease` 结束后将 **`direct` 变体**复制为 Flutter 默认查找的 `app-<mode>.apk`，使裸 `flutter build apk` 等命令能成功（默认渠道与 `scripts/build-android.sh` 一致）。不要在 `pubspec.yaml` 设置全局 `default-flavor`，否则 macOS / iOS 也会被套用 Android flavor，并触发 Xcode scheme 选择错误。

## 多平台构建与打包（脚本目录：`app/scripts/`）

国内 / 出海由编译期 `--dart-define=OVERSEAS_BUILD=false|true` 区分（与 [`lib/config/env.dart`](lib/config/env.dart) 一致）。单包用 **`--overseas`**（Windows：**`-Overseas`**）；**`--all`**（Windows：**`-All`**）一次性打出该平台全部发行变体，产物文件名含 **`cn` / `intl`**，落在同一 `app/dist/<版本>/` 目录。

| 平台 | 仅编译 | 单包打包 | 一次打全 (`--all`) |
| --- | --- | --- | --- |
| Android | `build-android.sh` [`--overseas`] | `package_android.sh` [`--overseas`] [`--play`] | `--all`：cn/intl **split** APK（arm64-v8a）+ intl play AAB；versionCode 同 pubspec build-number |
| macOS | `build-macos.sh` [`--overseas`] | `package_macos.sh` [`--overseas`] | 国内 + 出海 ZIP |
| iOS | `build-ios.sh` [`--overseas`] | `package_ios.sh` [`--overseas`] | 国内 + 出海 IPA（双 Bundle ID，见下） |
| Windows | `build-windows.ps1` [`-Overseas`] | `package_windows.ps1` [`-Overseas`] | 国内 + 出海 ZIP/MSIX/Setup |

示例：`./scripts/package_android.sh --all`；`.\app\scripts\package_windows.ps1 -All`。

### iOS 双 Bundle（`cn` / `intl` flavor）

Xcode 使用 **`cn`**（国内）与 **`intl`**（国际）两套 scheme / build configuration，与 `OVERSEAS_BUILD` 对齐：

| Flavor | `OVERSEAS_BUILD` | Bundle ID |
| --- | --- | --- |
| `cn`（默认） | `false` | `dev.ultrasend.app.cn` |
| `intl` | `true` | `dev.ultrasend.app` |

- 打包：`./scripts/package_ios.sh --all`（或 `build-ios.sh` / `package_ios.sh` 加 `--overseas` 打 intl）
- 本地运行：`flutter run -d <device> --flavor cn`；国际：`--flavor intl --dart-define=OVERSEAS_BUILD=true`
- Apple 证书与 App Group 清单见 [`docs/ios-dual-bundle-apple-setup.md`](../docs/ios-dual-bundle-apple-setup.md)
- 勿在 `pubspec.yaml` 设置全局 `default-flavor`（会影响 macOS / Android）

在 **`app/`** 下执行 shell 脚本；Windows 可从仓库根目录调用 `.\app\scripts\...`。根目录 `.\scripts\package_windows.ps1` 为兼容转发。详见 [`scripts/windows-packaging.md`](../scripts/windows-packaging.md)。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
