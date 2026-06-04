import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { DevicesApi, DeviceDto } from '../network/DevicesApi';

@Entry
@Component
struct DevicesPage {
  @State devices: DeviceDto[] = [];
  @State editName: string = '';
  @State selectedId: string = '';

  aboutToAppear(): void {
    void this.reload();
  }

  private async reload(): Promise<void> {
    try {
      this.devices = await DevicesApi.list();
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async saveName(): Promise<void> {
    if (this.selectedId.length === 0 || this.editName.trim().length === 0) {
      promptAction.showToast({ message: '请选择设备并输入名称' });
      return;
    }
    try {
      await DevicesApi.update(this.selectedId, this.editName.trim());
      promptAction.showToast({ message: '已更新' });
      await this.reload();
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .onClick(() => {
            router.back();
          })
        Text('设备').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
        Button('刷新')
          .type(ButtonType.Normal)
          .onClick(() => {
            void this.reload();
          })
      }
      .padding(12)
      .width('100%')

      TextInput({ placeholder: '新名称' })
        .margin({ left: 12, right: 12 })
        .onChange((v: string) => {
          this.editName = v;
        })
      Button('保存名称')
        .margin({ left: 12, right: 12, top: 8 })
        .onClick(() => {
          void this.saveName();
        })

      List({ space: 6 }) {
        ForEach(this.devices, (d: DeviceDto) => {
          ListItem() {
            Column() {
              Text(d.name).fontSize(16).fontWeight(FontWeight.Medium)
              Text(`${d.deviceId}`).fontSize(11).opacity(0.55).margin({ top: 4 })
              Text(`平台 ${d.platform ?? '-'}`)
                .fontSize(12)
                .opacity(0.65)
                .margin({ top: 4 })
            }
            .padding(12)
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .onClick(() => {
              this.selectedId = d.deviceId;
              this.editName = d.name;
              promptAction.showToast({ message: '已选中，可修改名称后保存' });
            })
          }
        }, (d: DeviceDto) => d.deviceId)
      }
      .layoutWeight(1)
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
  }
}
