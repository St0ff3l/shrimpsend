import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { AuthApi } from '../network/AuthApi';
import { ApiSession } from '../network/ApiSession';
import { getOrCreateDeviceId, getAuthPlatformLabel } from '../storage/DeviceIdentity';
import { AppLogFile } from '../services/AppLogFile';
import { AppTokens } from '../ui/theme/AppTokens';

@Entry
@Component
struct LoginPage {
  @State email: string = '';
  @State password: string = '';
  @State code: string = '';
  @State useCode: boolean = false;
  @State loading: boolean = false;

  private async doLogin(): Promise<void> {
    if (this.email.trim().length === 0) {
      promptAction.showToast({ message: '请输入邮箱' });
      return;
    }
    this.loading = true;
    try {
      const deviceId = await getOrCreateDeviceId();
      const platform = getAuthPlatformLabel();
      if (this.useCode) {
        if (this.code.trim().length !== 6) {
          promptAction.showToast({ message: '请输入 6 位验证码' });
          return;
        }
        const auth =
          await AuthApi.loginByCode(this.email, this.code, deviceId, platform);
        ApiSession.setTokens(auth.accessToken, auth.refreshToken, auth.userId);
        await ApiSession.persist();
        AppLogFile.append(`login code ok user=${auth.userId}`);
      } else {
        if (this.password.length === 0) {
          promptAction.showToast({ message: '请输入密码' });
          return;
        }
        const auth = await AuthApi.login(this.email, this.password, deviceId, platform);
        ApiSession.setTokens(auth.accessToken, auth.refreshToken, auth.userId);
        await ApiSession.persist();
        AppLogFile.append(`login pwd ok user=${auth.userId}`);
      }
      await router.replaceUrl({ url: 'pages/ChatPage' });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    } finally {
      this.loading = false;
    }
  }

  private async sendLoginCode(): Promise<void> {
    if (this.email.trim().length === 0) {
      promptAction.showToast({ message: '请先填邮箱' });
      return;
    }
    try {
      const deviceId = await getOrCreateDeviceId();
      const platform = getAuthPlatformLabel();
      await AuthApi.sendVerificationCode(this.email, 'LOGIN', deviceId, platform);
      promptAction.showToast({ message: '验证码已发送' });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: AppTokens.spaceMd }) {
          Text('登录虾传')
            .fontSize(AppTokens.fontTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: AppTokens.spaceSm })

          Row({ space: AppTokens.spaceMd }) {
            Button(this.useCode ? '当前：验证码' : '当前：密码')
              .layoutWeight(1)
              .height(AppTokens.controlHeight)
              .type(ButtonType.Normal)
              .fontColor($r('app.color.accent_primary'))
              .onClick(() => {
                this.useCode = !this.useCode;
              })
          }

          TextInput({ placeholder: '邮箱' })
            .width('100%')
            .height(AppTokens.controlHeight)
            .backgroundColor($r('app.color.chat_system_surface'))
            .borderRadius(AppTokens.radiusSm)
            .padding({ left: AppTokens.spaceMd, right: AppTokens.spaceMd })
            .onChange((v: string) => {
              this.email = v;
            })

          if (!this.useCode) {
            TextInput({ placeholder: '密码' })
              .width('100%')
              .height(AppTokens.controlHeight)
              .type(InputType.Password)
              .backgroundColor($r('app.color.chat_system_surface'))
              .borderRadius(AppTokens.radiusSm)
              .padding({ left: AppTokens.spaceMd, right: AppTokens.spaceMd })
              .onChange((v: string) => {
                this.password = v;
              })
          } else {
            Row({ space: AppTokens.spaceSm }) {
              TextInput({ placeholder: '6 位验证码' })
                .layoutWeight(1)
                .height(AppTokens.controlHeight)
                .backgroundColor($r('app.color.chat_system_surface'))
                .borderRadius(AppTokens.radiusSm)
                .padding({ left: AppTokens.spaceMd, right: AppTokens.spaceMd })
                .onChange((v: string) => {
                  this.code = v;
                })
              Button('发码')
                .height(AppTokens.controlHeight)
                .enabled(!this.loading)
                .type(ButtonType.Normal)
                .fontColor($r('app.color.accent_primary'))
                .onClick(() => {
                  void this.sendLoginCode();
                })
            }
            .width('100%')
          }

          Button(this.loading ? '请稍候…' : '进入')
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor($r('app.color.accent_primary_text'))
            .enabled(!this.loading)
            .onClick(() => {
              void this.doLogin();
            })

          Button('注册账号')
            .type(ButtonType.Normal)
            .width('100%')
            .height(AppTokens.controlHeight)
            .fontColor($r('app.color.accent_primary'))
            .onClick(() => {
              void router.pushUrl({ url: 'pages/RegisterPage' });
            })
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.auth_form_max_width') })
        .padding(AppTokens.spaceXl)
        .backgroundColor($r('app.color.card_surface'))
        .borderRadius(AppTokens.radiusMd)
      }
      .width('100%')
      .padding(AppTokens.spaceLg)
      .alignItems(HorizontalAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
