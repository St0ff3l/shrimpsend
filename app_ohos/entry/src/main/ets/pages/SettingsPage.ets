import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { AppThemeStore } from '../theme/AppThemeStore';
import { AppTokens } from '../ui/theme/AppTokens';
import { SettingsNavRow } from '../ui/settings/SettingsNavRow';

@Entry
@Component
struct SettingsPage {
  build() {
    Column({ space: AppTokens.spaceMd }) {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .fontColor($r('app.color.accent_primary'))
          .onClick(() => {
            router.back();
          })
        Text('设置')
          .fontSize(AppTokens.fontHeadline)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(56)
      }
      .width('100%')
      .padding({
        left: AppTokens.spaceMd,
        right: AppTokens.spaceMd,
        top: AppTokens.spaceSm,
        bottom: AppTokens.spaceSm
      })

      Scroll() {
        Column({ space: AppTokens.spaceSm }) {
          SettingsNavRow({ label: '账号与安全', targetUrl: 'pages/AccountPage' })
          SettingsNavRow({ label: 'S3 存储', targetUrl: 'pages/S3SettingsPage' })
          SettingsNavRow({ label: '版本历史', targetUrl: 'pages/VersionHistoryPage' })
          SettingsNavRow({ label: '应用日志', targetUrl: 'pages/AppLogPage' })
          SettingsNavRow({ label: '扫码', targetUrl: 'pages/QrScanPage' })
          SettingsNavRow({ label: '会员', targetUrl: 'pages/MembershipPage' })

          Column({ space: AppTokens.spaceSm }) {
            Text('外观')
              .fontSize(AppTokens.fontCaption)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
              .padding({ left: AppTokens.spaceXs })

            Button('主题：深色（持久化）')
              .width('100%')
              .height(AppTokens.controlHeight)
              .type(ButtonType.Normal)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.card_surface'))
              .borderRadius(AppTokens.radiusSm)
              .border({ width: 1, color: $r('app.color.divider_line') })
              .onClick(() => {
                void AppThemeStore.setChoice('dark').then(() => {
                  promptAction.showToast({
                    message: '已保存主题偏好（可与 EntryAbility 配色联动扩展）'
                  });
                });
              })

            Button('主题：浅色')
              .width('100%')
              .height(AppTokens.controlHeight)
              .type(ButtonType.Normal)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.card_surface'))
              .borderRadius(AppTokens.radiusSm)
              .border({ width: 1, color: $r('app.color.divider_line') })
              .onClick(() => {
                void AppThemeStore.setChoice('light').then(() => {
                  promptAction.showToast({ message: '已保存浅色偏好' });
                });
              })
          }
          .width('100%')
          .padding(AppTokens.spaceLg)
          .backgroundColor($r('app.color.card_surface'))
          .borderRadius(AppTokens.radiusMd)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.auth_form_max_width') })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTokens.spaceLg,
      right: AppTokens.spaceLg,
      top: AppTokens.spaceSm,
      bottom: AppTokens.spaceLg
    })
    .backgroundColor($r('app.color.page_background'))
  }
}
