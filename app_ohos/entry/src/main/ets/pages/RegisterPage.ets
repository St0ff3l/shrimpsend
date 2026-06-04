import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { AuthApi } from '../network/AuthApi';
import { ApiSession } from '../network/ApiSession';
import { getOrCreateDeviceId, getAuthPlatformLabel } from '../storage/DeviceIdentity';
import { AppLogFile } from '../services/AppLogFile';
import { AppTokens } from '../ui/theme/AppTokens';

@Entry
@Component
struct RegisterPage {
  @State email: string = '';
  @State password: string = '';
  @State code: string = '';
  @State username: string = '';
  @State loading: boolean = false;

  private async sendRegCode(): Promise<void> {
    if (this.email.trim().length === 0) {
      promptAction.showToast({ message: '请先填邮箱' });
      return;
    }
    try {
      await AuthApi.sendVerificationCode(this.email);
      promptAction.showToast({ message: '验证码已发送' });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async submit(): Promise<void> {
    if (this.email.trim().length === 0 || this.password.length === 0 || this.code.trim().length === 0) {
      promptAction.showToast({ message: '请填写完整' });
      return;
    }
    this.loading = true;
    try {
      const deviceId = await getOrCreateDeviceId();
      const platform = getAuthPlatformLabel();
      const un = this.username.trim().length > 0 ? this.username.trim() : undefined;
      const auth =
        await AuthApi.register(this.email, this.password, this.code, deviceId, platform, un);
      ApiSession.setTokens(auth.accessToken, auth.refreshToken, auth.userId);
      await ApiSession.persist();
      AppLogFile.append(`register ok user=${auth.userId}`);
      promptAction.showToast({ message: '注册成功' });
      await router.replaceUrl({ url: 'pages/ChatPage' });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    } finally {
      this.loading = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: AppTokens.spaceMd }) {
          Text('注册')
            .fontSize(AppTokens.fontTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: AppTokens.spaceSm })

          TextInput({ placeholder: '邮箱' })
            .width('100%')
            .height(AppTokens.controlHeight)
            .backgroundColor($r('app.color.chat_system_surface'))
            .borderRadius(AppTokens.radiusSm)
            .padding({ left: AppTokens.spaceMd, right: AppTokens.spaceMd })
            .onChange((v: string) => {
              this.email = v;
            })

          TextInput({ placeholder: '用户名（可选）' })
            .width('100%')
            .height(AppTokens.controlHeight)
            .backgroundColor($r('app.color.chat_system_surface'))
            .borderRadius(AppTokens.radiusSm)
            .padding({ left: AppTokens.spaceMd, right: AppTokens.spaceMd })
            .onChange((v: string) => {
              this.username = v;
            })

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

          Row({ space: AppTokens.spaceSm }) {
            TextInput({ placeholder: '邮箱验证码' })
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
              .type(ButtonType.Normal)
              .fontColor($r('app.color.accent_primary'))
              .onClick(() => {
                void this.sendRegCode();
              })
          }
          .width('100%')

          Button(this.loading ? '提交中…' : '注册并登录')
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor($r('app.color.accent_primary_text'))
            .enabled(!this.loading)
            .onClick(() => {
              void this.submit();
            })

          Button('返回登录')
            .type(ButtonType.Normal)
            .width('100%')
            .height(AppTokens.controlHeight)
            .fontColor($r('app.color.accent_primary'))
            .onClick(() => {
              router.back();
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
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
