import router from '@ohos.router';
import { AppTokens } from '../theme/AppTokens';

@Component
export struct SettingsNavRow {
  @Prop label: string = '';
  /** 例如 pages/AccountPage */
  @Prop targetUrl: string = '';

  build() {
    Row() {
      Text(this.label)
        .fontSize(AppTokens.fontBody)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({
      left: AppTokens.spaceLg,
      right: AppTokens.spaceLg,
      top: AppTokens.spaceMd,
      bottom: AppTokens.spaceMd
    })
    .backgroundColor($r('app.color.card_surface'))
    .borderRadius(AppTokens.radiusSm)
    .border({ width: 1, color: $r('app.color.divider_line') })
    .onClick(() => {
      if (this.targetUrl.length > 0) {
        void router.pushUrl({ url: this.targetUrl });
      }
    })
  }
}
