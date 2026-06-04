# iOS 国内/海外双 Bundle — Apple Developer 清单

在本地 Xcode 能 Archive 之前，需在 [Apple Developer](https://developer.apple.com) 与 App Store Connect 完成以下配置。

## Bundle ID 分配

| 市场 | 主 App | Share Extension | App Group |
|------|--------|-----------------|-----------|
| 国际 (intl) | `dev.ultrasend.app` | `dev.ultrasend.app.ShareExtension` | `group.dev.ultrasend.app` |
| 国内 (cn) | `dev.ultrasend.app.cn` | `dev.ultrasend.app.cn.ShareExtension` | `group.dev.ultrasend.app.cn` |

国际版沿用现有标识；国内版为**新建** App ID。

## 国内包（新建）

1. **Identifiers → App IDs**：注册 `dev.ultrasend.app.cn`
2. **App Groups**：创建 `group.dev.ultrasend.app.cn`，并勾选到主 App 与 Extension
3. **Identifiers**：注册 `dev.ultrasend.app.cn.ShareExtension`（App Extension 类型），启用同一 App Group
4. **Profiles**：为 Debug/Release 各生成主 App + Extension 描述文件（Automatic Signing 可在 Xcode 中自动完成）
5. **App Store Connect**：新建 App，Bundle ID 选 `dev.ultrasend.app.cn`
6. **国内 iOS IAP + RevenueCat**：3 个终身买断商品与 RC 国内 Project 配置见 [revenuecat-cn-ios-setup.md](./revenuecat-cn-ios-setup.md)

## 国际包（沿用）

- 确认 `dev.ultrasend.app`、Extension、App Group 已存在
- RevenueCat 继续绑定 `dev.ultrasend.app`（见 [revenuecat-overseas-setup.md](./revenuecat-overseas-setup.md)）

## 签名与 App Group（常见报错）

若出现：

> Provisioning profile doesn't match the entitlements file's value for the com.apple.security.application-groups entitlement

按下面顺序排查：

1. **Developer 门户**：已创建 App Group `group.dev.ultrasend.app.cn`，并勾选到 **`dev.ultrasend.app.cn`** 与 **`dev.ultrasend.app.cn.ShareExtension`** 两个 App ID（Capabilities → App Groups）。
2. **Xcode**：打开 `app/ios/Runner.xcworkspace`，选中 **Runner** 与 **Share Extension** target，Signing 使用同一 Team；对 **cn** scheme 可先 `Product → Clean Build Folder`。
3. **刷新描述文件**：Signing 切到 Manual 再切回 Automatic，或删除 `~/Library/MobileDevice/Provisioning Profiles` 里过期的 `dev.ultrasend.app.cn*` 后让 Xcode 重新生成。
4. 工程内 entitlements 已按 flavor 拆分（`Runner-cn.entitlements` / `Share Extension-cn.entitlements` 等），**勿**在 entitlements 里写 `$(CUSTOM_GROUP_ID)`（签名阶段不会展开，易与 Profile 不一致）。

国际 **intl** 包继续用 `group.dev.ultrasend.app`；若 intl 也报错，同样在门户确认该 Group 已挂在 `dev.ultrasend.app` 与 Extension 上。

## Xcode 里 Scheme 在哪、叫什么

- **Scheme**（工具栏中间 `Runner ▼`）：应选 **`cn`**（国区）或 **`intl`**（国际），不是 `Release-cn`。
- **`Release-cn`** 是 **Build Configuration**（在 Signing / Build Settings 顶部切换），不是 Scheme 名称。

若 Scheme 下拉里只有 `Runner`、没有 `cn` / `intl`：

1. 确认用 **`app/ios/Runner.xcworkspace`** 打开（不要只开 `.xcodeproj`）。
2. 菜单 **Product → Scheme → Manage Schemes…**
3. 在列表里找 **`cn`、`intl`**，勾选 **Shared**（共享）和 **Show**（显示）。
4. 若没有这两项：点左下角 **+**，Name 填 `cn`，Target 选 **Runner**，再 **Edit Scheme** → **Archive** → Build Configuration 选 **Release-cn**；`intl` 同理用 **Release-intl**。
5. 完全退出 Xcode 后重开；或确认本机已有 `Runner.xcodeproj/xcshareddata/xcschemes/cn.xcscheme` 与 `intl.xcscheme`（与仓库同步）。

不打开 Xcode 也可命令行打包（只要工程文件齐全）：

```bash
cd app
flutter build ipa --release --flavor cn --dart-define=OVERSEAS_BUILD=false
flutter build ipa --release --flavor intl --dart-define=OVERSEAS_BUILD=true
```

## 本地构建

```bash
cd app
./scripts/package_ios.sh --all    # cn + intl 各一份 IPA（intl 步骤会自动 xcodebuild clean，耗时较长）
./scripts/build-ios.sh --overseas ipa   # 仅 intl（含 xcodebuild clean）
./scripts/build-ios.sh ipa              # 仅 cn
```

`--all` 模式下 intl 步骤会在 `flutter build ipa` 前执行 `xcodebuild clean -scheme intl -configuration Release-intl`，避免 cn 构建缓存导致 intl 包仍带 `.cn` Bundle ID。

## 打包后验证

```bash
VERSION=1.3.3.35   # 替换为 pubspec 版本（+ 改为 .）

# cn 包 Bundle ID
unzip -p "app/dist/$VERSION/Shrimpsend-ios-cn-$VERSION.ipa" Payload/*.app/Info.plist \
  | plutil -extract CFBundleIdentifier raw -
# 期望: dev.ultrasend.app.cn

# intl 包 Bundle ID
unzip -p "app/dist/$VERSION/Shrimpsend-ios-intl-$VERSION.ipa" Payload/*.app/Info.plist \
  | plutil -extract CFBundleIdentifier raw -
# 期望: dev.ultrasend.app（无 .cn）

# Display Name（可选）
unzip -p "app/dist/$VERSION/Shrimpsend-ios-cn-$VERSION.ipa" Payload/*.app/Info.plist \
  | plutil -extract CFBundleDisplayName raw -
# 期望: 虾传

unzip -p "app/dist/$VERSION/Shrimpsend-ios-intl-$VERSION.ipa" Payload/*.app/Info.plist \
  | plutil -extract CFBundleDisplayName raw -
# 期望: ShrimpSend
```

打包脚本会在复制到 `dist/` 前校验 Bundle ID；不匹配时会报错退出，不会写入错误产物。

## 工程自检（仓库侧）

在 `app/ios/` 执行（需已 `pod install`）：

```bash
./scripts/verify_ios_flavors.sh
```

通过即表示 `project.pbxproj` 中 cn/intl Build Configuration、Bundle ID、分 flavor entitlements 与 Pods xcconfig 已对齐。**仍需**在 Apple Developer 门户完成上文「国内包（新建）」步骤后，才能在真机 / Archive 上使用 `dev.ultrasend.app.cn` 签名。
