import router from '@ohos.router';
import { ApiSession } from '../network/ApiSession';
import { ChatRdb } from '../storage/ChatRdb';
import { getAbilityContext } from '../common/AppContext';

@Entry
@Component
struct Splash {
  @State loading: boolean = true;

  aboutToAppear(): void {
    void this.bootstrap();
  }

  async bootstrap(): Promise<void> {
    try {
      await ApiSession.loadFromStorage();
      await ChatRdb.init(getAbilityContext());
      ApiSession.setOnSessionInvalidated(async () => {
        await router.replaceUrl({ url: 'pages/LoginPage' });
      });
      if (ApiSession.hasLogin()) {
        await router.replaceUrl({ url: 'pages/ChatPage' });
      } else {
        await router.replaceUrl({ url: 'pages/LoginPage' });
      }
    } catch (_) {
      await router.replaceUrl({ url: 'pages/LoginPage' });
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      LoadingProgress().width(48).height(48)
      Text('虾传').fontSize(22).margin({ top: 16 })
      Text('加载中…').fontSize(14).opacity(0.6).margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
