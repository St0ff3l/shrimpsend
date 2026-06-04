import router from '@ohos.router';

@Entry
@Component
struct MembershipPage {
  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回').type(ButtonType.Normal).onClick(() => {
          router.back();
        })
        Text('会员').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .padding(12)
      .width('100%')

      Text('纯血鸿蒙侧会员能力需与产品确认：华为 IAP / 服务端 entitlement 校验，替代 RevenueCat + 支付宝。').padding(16)
    }
    .width('100%')
    .height('100%')
  }
}
