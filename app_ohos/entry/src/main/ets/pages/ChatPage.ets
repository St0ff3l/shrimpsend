import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import util from '@ohos.util';
import { ApiSession } from '../network/ApiSession';
import { MessagesApi, MessageEnvelope } from '../network/MessagesApi';
import { DevicesApi } from '../network/DevicesApi';
import { ChatRdb, LocalChatRow } from '../storage/ChatRdb';
import { getOrCreateDeviceId, getDeviceName, getAuthPlatformLabel } from '../storage/DeviceIdentity';
import { RealtimeHub } from '../realtime/RealtimeHub';
import { ShareInbox } from '../share/ShareInbox';
import { AppLogFile } from '../services/AppLogFile';
import { Log } from '../common/Logger';
import {
  formatChatTime, MessageCategory, MessagePreviewFormatter
} from '../ui/chat/MessagePreviewFormatter';
import { ChatBubbleItem } from '../ui/chat/ChatBubbleItem';
import { AppTokens } from '../ui/theme/AppTokens';

interface ChatDisplayLine {
  key: string;
  title: string;
  subtitle: string;
  category: MessageCategory;
  self: boolean;
  ts: number;
  timeLabel: string;
}

const TAG = 'ChatPage';

@Entry
@Component
struct ChatPage {
  @State lines: ChatDisplayLine[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  private selfDeviceId: string = '';

  aboutToAppear(): void {
    void this.bootstrap();
  }

  aboutToDisappear(): void {
    RealtimeHub.disconnect();
  }

  private async bootstrap(): Promise<void> {
    try {
      this.selfDeviceId = await getOrCreateDeviceId();
      const name = await getDeviceName();
      const platform = getAuthPlatformLabel();
      await DevicesApi.register(this.selfDeviceId, name, platform);
      await this.pullHistory();
      await this.refreshFromDb();
      await RealtimeHub.connect((_: string, data: string) => {
        void this.onRealtimePayload(data);
      });
      const n = ShareInbox.peekCount();
      if (n > 0) {
        ShareInbox.takeAll();
        promptAction.showToast({
          message: `收到 ${n} 个系统分享项（文件待发后续接入）`
        });
      }
    } catch (e) {
      Log.warn(TAG, 'bootstrap %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: `${e}` });
    }
  }

  private async pullHistory(): Promise<void> {
    const uid = ApiSession.getUserId();
    const hist = await MessagesApi.getHistory(50);
    for (let i = 0; i < hist.length; i++) {
      await ChatRdb.upsertMessage(uid, hist[i]);
    }
  }

  private async refreshFromDb(): Promise<void> {
    const uid = ApiSession.getUserId();
    const rows = await ChatRdb.loadRecent(uid, 100);
    const asc: LocalChatRow[] = [];
    for (let i = rows.length - 1; i >= 0; i--) {
      asc.push(rows[i]);
    }
    const out: ChatDisplayLine[] = [];
    for (let j = 0; j < asc.length; j++) {
      out.push(ChatPage.rowToLine(asc[j], this.selfDeviceId));
    }
    this.lines = out;
  }

  private static rowToLine(row: LocalChatRow, selfId: string): ChatDisplayLine {
    const pv = MessagePreviewFormatter.format(row.type, row.payloadJson);
    return {
      key: row.id,
      title: pv.title,
      subtitle: pv.subtitle,
      category: pv.category,
      self: row.fromDeviceId === selfId,
      ts: row.ts,
      timeLabel: formatChatTime(row.ts)
    };
  }

  private async onRealtimePayload(data: string): Promise<void> {
    try {
      const uid = ApiSession.getUserId();
      const root = JSON.parse(data) as Record<string, Object>;
      let raw = root;
      const inner = root['data'];
      if (inner !== undefined && typeof inner === 'object') {
        raw = inner as Record<string, Object>;
      }
      const env = MessagesApi.parseEnvelope(raw);
      await ChatRdb.upsertMessage(uid, env);
      await this.refreshFromDb();
    } catch (e) {
      Log.warn(TAG, 'realtime parse %{public}s', JSON.stringify(e));
    }
  }

  private async sendText(): Promise<void> {
    const t = this.draft.trim();
    if (t.length === 0) {
      return;
    }
    this.busy = true;
    try {
      const localId: string = util.generateRandomUUID(true);
      const ts = Date.now();
      const payloadObj: Record<string, Object> = {};
      payloadObj['text'] = t;
      payloadObj['localId'] = localId;
      const msg: MessageEnvelope = {
        type: 'text',
        payload: payloadObj,
        fromDeviceId: this.selfDeviceId,
        ts: ts
      };
      await MessagesApi.sendMessage(msg);
      this.draft = '';
      AppLogFile.append('send text ok');
      await this.pullHistory();
      await this.refreshFromDb();
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('虾传')
          .fontSize(AppTokens.fontHeadline)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button('设备')
          .fontSize(14)
          .type(ButtonType.Normal)
          .fontColor($r('app.color.accent_primary'))
          .onClick(() => {
            void router.pushUrl({ url: 'pages/DevicesPage' });
          })
        Button('文件')
          .fontSize(14)
          .type(ButtonType.Normal)
          .fontColor($r('app.color.accent_primary'))
          .onClick(() => {
            void router.pushUrl({ url: 'pages/FileManagerPage' });
          })
        Button('设置')
          .fontSize(14)
          .type(ButtonType.Normal)
          .fontColor($r('app.color.accent_primary'))
          .onClick(() => {
            void router.pushUrl({ url: 'pages/SettingsPage' });
          })
      }
      .padding({
        left: AppTokens.spaceLg,
        right: AppTokens.spaceLg,
        top: AppTokens.spaceMd,
        bottom: AppTokens.spaceMd
      })
      .width('100%')
      .backgroundColor($r('app.color.card_surface'))

      List({ space: 0 }) {
        ForEach(this.lines, (item: ChatDisplayLine) => {
          ListItem() {
            ChatBubbleItem({
              title: item.title,
              subtitle: item.subtitle,
              timeLabel: item.timeLabel,
              self: item.self,
              category: item.category
            })
          }
        }, (item: ChatDisplayLine) => item.key)
      }
      .layoutWeight(1)
      .padding({
        left: AppTokens.spaceSm,
        right: AppTokens.spaceSm,
        top: AppTokens.spaceSm,
        bottom: AppTokens.spaceSm
      })
      .backgroundColor($r('app.color.chat_page_background'))

      Row({ space: AppTokens.spaceSm }) {
        TextInput({
          text: this.draft,
          placeholder: '发送文字…'
        })
          .layoutWeight(1)
          .height(AppTokens.controlHeight)
          .backgroundColor($r('app.color.card_surface'))
          .borderRadius(AppTokens.radiusSm)
          .padding({ left: AppTokens.spaceMd, right: AppTokens.spaceMd })
          .onChange((v: string) => {
            this.draft = v;
          })
        Button(this.busy ? '…' : '发送')
          .height(AppTokens.controlHeight)
          .fontColor($r('app.color.accent_primary_text'))
          .backgroundColor($r('app.color.accent_primary'))
          .borderRadius(AppTokens.radiusSm)
          .enabled(!this.busy)
          .onClick(() => {
            void this.sendText();
          })
      }
      .padding({
        left: AppTokens.spaceMd,
        right: AppTokens.spaceMd,
        top: AppTokens.spaceSm,
        bottom: AppTokens.spaceMd
      })
      .width('100%')
      .backgroundColor($r('app.color.card_surface'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.chat_page_background'))
  }
}
