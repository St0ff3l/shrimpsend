import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { ApiSession } from '../network/ApiSession';
import { AuthApi } from '../network/AuthApi';
import { UserApi } from '../network/UserApi';
import { getOrCreateDeviceId } from '../storage/DeviceIdentity';
import { AppLogFile } from '../services/AppLogFile';

@Entry
@Component
struct AccountPage {
  @State email: string = '';
  @State userId: string = '';
  @State code: string = '';
  @State newPwd: string = '';
  @State confirmPwd: string = '';
  @State codeSending: boolean = false;
  @State cooldown: number = 0;
  private cooldownTimer: number = -1;

  aboutToAppear(): void {
    void this.load();
  }

  aboutToDisappear(): void {
    if (this.cooldownTimer >= 0) {
      clearInterval(this.cooldownTimer);
      this.cooldownTimer = -1;
    }
  }

  private async load(): Promise<void> {
    try {
      const p = await UserApi.fetchProfile();
      this.email = p.email;
      this.userId = p.userId;
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private startCooldown(): void {
    this.cooldown = 60;
    if (this.cooldownTimer >= 0) {
      clearInterval(this.cooldownTimer);
    }
    this.cooldownTimer = setInterval(() => {
      if (this.cooldown <= 1) {
        this.cooldown = 0;
        if (this.cooldownTimer >= 0) {
          clearInterval(this.cooldownTimer);
          this.cooldownTimer = -1;
        }
      } else {
        this.cooldown--;
      }
    }, 1000);
  }

  private async sendCode(): Promise<void> {
    if (this.codeSending || this.cooldown > 0) {
      return;
    }
    this.codeSending = true;
    try {
      await UserApi.sendChangePasswordCode();
      this.startCooldown();
      promptAction.showToast({ message: '验证码已发送' });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    } finally {
      this.codeSending = false;
    }
  }

  private async changePwd(): Promise<void> {
    const trimmedCode = this.code.trim();
    if (trimmedCode.length === 0) {
      promptAction.showToast({ message: '请输入验证码' });
      return;
    }
    if (this.newPwd.length < 6) {
      promptAction.showToast({ message: '新密码至少需要6个字符' });
      return;
    }
    if (this.newPwd !== this.confirmPwd) {
      promptAction.showToast({ message: '两次输入的密码不一致' });
      return;
    }
    try {
      await UserApi.changePassword(trimmedCode, this.newPwd);
      promptAction.showToast({ message: '已修改密码' });
      this.code = '';
      this.newPwd = '';
      this.confirmPwd = '';
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async logout(): Promise<void> {
    try {
      const did = await getOrCreateDeviceId();
      await AuthApi.logout(did);
    } catch (_) {
      // ignore
    }
    await ApiSession.clear();
    AppLogFile.append('logout');
    await router.replaceUrl({ url: 'pages/LoginPage' });
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Button('返回').type(ButtonType.Normal).onClick(() => {
            router.back();
          })
          Text('账号').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
        }
        .padding(12)
        .width('100%')

        Text(`邮箱 ${this.email}`).margin({ left: 16, right: 16 })
        Text(`用户 ID ${this.userId}`).fontSize(12).opacity(0.6).margin({ left: 16, right: 16 })

        Text('修改密码').fontWeight(FontWeight.Medium).margin({ left: 16, top: 16 })
        Text('验证码将发送到上方邮箱').fontSize(12).opacity(0.6).margin({ left: 16, right: 16 })

        Row({ space: 8 }) {
          TextInput({ placeholder: '6位验证码', text: this.code })
            .type(InputType.Number)
            .layoutWeight(1)
            .onChange((v: string) => {
              this.code = v;
            })
          Button(this.codeSending ? '发送中' : (this.cooldown > 0 ? `${this.cooldown}s` : '发送验证码'))
            .enabled(!this.codeSending && this.cooldown <= 0)
            .onClick(() => {
              void this.sendCode();
            })
        }
        .margin({ left: 16, right: 16 })
        .width('100%')

        TextInput({ placeholder: '新密码' }).type(InputType.Password).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.newPwd = v;
        })
        TextInput({ placeholder: '确认新密码' }).type(InputType.Password).margin({ left: 16, right: 16 }).onChange((v: string) => {
          this.confirmPwd = v;
        })
        Button('提交修改').margin({ left: 16, right: 16 }).onClick(() => {
          void this.changePwd();
        })

        Button('退出登录')
          .width('90%')
          .margin({ top: 32 })
          .backgroundColor('#FF3B30')
          .fontColor('#FFFFFF')
          .onClick(() => {
            void this.logout();
          })
      }
    }
    .width('100%')
    .height('100%')
  }
}
