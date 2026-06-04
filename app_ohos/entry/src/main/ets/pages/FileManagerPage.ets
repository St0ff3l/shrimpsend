import router from '@ohos.router';
import { MdnsDiscovery } from '../discovery/MdnsDiscovery';
import { LanProtocolTransfer } from '../transfer/LanProtocolTransfer';

@Entry
@Component
struct FileManagerPage {
  aboutToAppear(): void {
    MdnsDiscovery.logLocalIpv4Hint();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回').type(ButtonType.Normal).onClick(() => {
          router.back();
        })
        Text('文件').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .padding(12)
      .width('100%')

      Text('文件管理与传输入口（占位）').fontSize(14).margin({ left: 16, right: 16 })
      Text(`LAN：${LanProtocolTransfer.normalizeBase('http://127.0.0.1:9')}/transfer`).fontSize(11).opacity(0.55).margin({
        left: 16,
        right: 16
      })
      Text('S3：聊天页外可通过 S3SimpleTransfer 调用预签名上传（与 Flutter 一致）。').fontSize(11).opacity(0.55).margin({
        left: 16,
        right: 16
      })
    }
    .width('100%')
    .height('100%')
  }
}
