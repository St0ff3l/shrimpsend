import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct QrScanPage {
  @State sessionHint: string = '';

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回').type(ButtonType.Normal).onClick(() => {
          router.back();
        })
        Text('扫码登录').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .padding(12)
      .width('100%')

      Text('相机扫码需接入 Scan Kit / 自定义扫码组件；此处为占位。').margin({ left: 16, right: 16 })
      TextInput({ placeholder: '可粘贴 PC 端展示的 sessionId（若后端支持）' }).margin({ left: 16, right: 16 }).onChange((v: string) => {
        this.sessionHint = v;
      })
      Button('提示').onClick(() => {
        promptAction.showToast({
          message: '完整流程：createQrSession → 轮询 getQrStatus（见 Flutter qr 相关 API）'
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}
