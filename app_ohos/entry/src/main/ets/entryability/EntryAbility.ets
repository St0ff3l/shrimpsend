import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { setAbilityContext } from '../common/AppContext';
import { setRefreshTokenHandler } from '../network/HttpHelper';
import { AuthApi } from '../network/AuthApi';
import { ShareInbox } from '../share/ShareInbox';

const DOMAIN = 0x3201;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'Entry', 'setColorMode %{public}s', JSON.stringify(err));
    }
    setAbilityContext(this.context);
    setRefreshTokenHandler(() => AuthApi.tryRefreshAndPersist());
    this.handleShareWant(want);
    hilog.info(DOMAIN, 'Entry', 'onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleShareWant(want);
  }

  private handleShareWant(want: Want): void {
    try {
      const uris = want.uri;
      if (uris !== undefined && uris !== null && `${uris}`.length > 0) {
        ShareInbox.push(`${uris}`);
      }
    } catch (e) {
      hilog.warn(DOMAIN, 'Entry', 'share want %{public}s', JSON.stringify(e));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'Entry', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'Entry', 'onWindowStageCreate');
    windowStage.loadContent('pages/Splash', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'Entry', 'loadContent %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'Entry', 'Splash loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'Entry', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'Entry', 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'Entry', 'onBackground');
  }
}
