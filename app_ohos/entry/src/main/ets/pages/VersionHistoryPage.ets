import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import bundleManager from '@ohos.bundle.bundleManager';
import { AppVersionApi, UpdateInfo } from '../network/AppVersionApi';

@Entry
@Component
struct VersionHistoryPage {
  @State items: UpdateInfo[] = [];
  @State localVer: string = '';

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    try {
      const infos = await AppVersionApi.fetchVersionHistory();
      this.items = infos;
      try {
        const bi = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
        this.localVer = `${bi.versionName} (${bi.versionCode})`;
      } catch (_) {
        this.localVer = '';
      }
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async checkUpdateTap(): Promise<void> {
    try {
      const j = await AppVersionApi.checkLatestJson();
      if (j === null) {
        promptAction.showToast({ message: '暂无可用的版本信息接口返回' });
        return;
      }
      promptAction.showToast({ message: `服务端 JSON：${JSON.stringify(j).substring(0, 120)}…` });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回').type(ButtonType.Normal).onClick(() => {
          router.back();
        })
        Text('版本').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .padding(12)
      .width('100%')

      Text(`本机 ${this.localVer}`).margin({ left: 16, bottom: 8 })
      Button('检查更新（latest.json）').margin({ left: 16, right: 16 }).onClick(() => {
        void this.checkUpdateTap();
      })

      List({ space: 8 }) {
        ForEach(this.items, (it: UpdateInfo) => {
          ListItem() {
            Column() {
              Text(`${it.version}  build ${it.buildNumber}`).fontWeight(FontWeight.Medium)
              if (it.releaseNotes.length > 0) {
                Text(it.releaseNotes).fontSize(12).margin({ top: 6 }).opacity(0.75)
              }
            }
            .padding(12)
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
          }
        }, (it: UpdateInfo) => `${it.version}_${it.buildNumber}`)
      }
      .layoutWeight(1)
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
  }
}
