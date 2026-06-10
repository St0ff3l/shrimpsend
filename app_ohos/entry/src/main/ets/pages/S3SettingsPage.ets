import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { S3Api, S3ConfigDetail } from '../network/S3Api';

@Entry
@Component
struct S3SettingsPage {
  @State endpoint: string = '';
  @State region: string = '';
  @State bucket: string = '';
  @State ak: string = '';
  @State sk: string = '';
  @State configured: boolean = false;

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    try {
      const c: S3ConfigDetail = await S3Api.getConfig();
      this.configured = c.configured;
      this.endpoint = c.endpoint ?? '';
      this.region = c.region ?? '';
      this.bucket = c.bucket ?? '';
      this.ak = c.accessKeyId ?? '';
      this.sk = '';
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async save(): Promise<void> {
    try {
      const body: Record<string, Object> = {
        'endpoint': this.endpoint,
        'region': this.region.length > 0 ? this.region : 'cn-east-1',
        'bucket': this.bucket,
        'accessKeyId': this.ak
      };
      if (this.sk.length > 0) {
        body['secretAccessKey'] = this.sk;
      }
      await S3Api.saveConfig(body);
      promptAction.showToast({ message: '已保存' });
      await this.load();
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async clear(): Promise<void> {
    try {
      await S3Api.clearConfig();
      promptAction.showToast({ message: '已清空' });
      await this.load();
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Row() {
          Button('返回').type(ButtonType.Normal).onClick(() => {
            router.back();
          })
          Text('S3').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
        }
        .padding(12)
        .width('100%')

        Text(this.configured ? '当前：已配置' : '当前：未配置')
          .margin({ left: 16 })
        TextInput({ placeholder: 'Endpoint' }).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.endpoint = v;
        })
        TextInput({ placeholder: 'Region' }).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.region = v;
        })
        TextInput({ placeholder: 'Bucket' }).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.bucket = v;
        })
        TextInput({ placeholder: 'Access Key Id' }).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.ak = v;
        })
        TextInput({ placeholder: 'Secret Access Key' }).type(InputType.Password).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.sk = v;
        })
        Row({ space: 12 }) {
          Button('保存').layoutWeight(1).onClick(() => {
            void this.save();
          })
          Button('清空').layoutWeight(1).type(ButtonType.Normal).onClick(() => {
            void this.clear();
          })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
  }
}
