import router from '@ohos.router';
import { AppLogFile } from '../services/AppLogFile';

@Entry
@Component
struct AppLogPage {
  @State content: string = '';

  aboutToAppear(): void {
    this.content = AppLogFile.readTail();
  }

  build() {
    Column() {
      Row() {
        Button('返回').type(ButtonType.Normal).onClick(() => {
          router.back();
        })
        Text('应用日志').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
        Button('刷新')
          .type(ButtonType.Normal)
          .onClick(() => {
            this.content = AppLogFile.readTail();
          })
      }
      .padding(12)
      .width('100%')

      Text(this.content.length > 0 ? this.content : '（暂无日志）')
        .fontSize(11)
        .fontFamily('monospace')
        .padding(12)
        .layoutWeight(1)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
