import { BusinessError } from '@ohos.base';
import webSocket from '@ohos.net.webSocket';
import util from '@ohos.util';
import { Log } from '../common/Logger';

const TAG = 'CentrifugoWs';

/**
 * Centrifugo JSON WebSocket 协议（对齐 Flutter centrifuge 订阅 user 频道）。
 * 文档：https://centrifugal.dev/docs/server/server_api#json-commands
 */
export class CentrifugoClient {
  private ws: webSocket.WebSocket | null = null;
  private connectDone: boolean = false;
  private pendingConnToken: string = '';
  private pendingChannel: string = '';
  private pendingSubToken: string = '';
  private onPublication: (channel: string, dataUtf8: string) => void = () => {
  };

  connect(
    wsUrl: string,
    connectionToken: string,
    channel: string,
    subscriptionToken: string,
    onPublication: (channel: string, dataUtf8: string) => void
  ): void {
    this.disconnect();
    this.connectDone = false;
    this.pendingConnToken = connectionToken;
    this.pendingChannel = channel;
    this.pendingSubToken = subscriptionToken;
    this.onPublication = onPublication;
    this.ws = webSocket.createWebSocket();

    this.ws.on('open', (err: BusinessError | null) => {
      if (err != null) {
        Log.error(TAG, 'open error %{public}s', JSON.stringify(err));
        return;
      }
      this.sendJson({
        'id': 1,
        'connect': {
          'token': connectionToken,
          'name': 'harmony'
        } as Record<string, Object>
      } as Record<string, Object>);
    });

    this.ws.on('message', (err: BusinessError | null, value: string | ArrayBuffer) => {
      if (err != null || value === undefined || value === null) {
        return;
      }
      const text = typeof value === 'string' ? value : CentrifugoClient.bufferToUtf8(value as ArrayBuffer);
      this.handleIncoming(text);
    });

    this.ws.on('close', (err: BusinessError | null) => {
      Log.warn(TAG, 'socket close %{public}s', err !== null ? JSON.stringify(err) : 'ok');
      this.connectDone = false;
    });

    this.ws.connect(wsUrl, (err: BusinessError | null) => {
      if (err != null) {
        Log.error(TAG, 'connect failed %{public}s', JSON.stringify(err));
      }
    });
  }

  disconnect(): void {
    if (this.ws !== null) {
      try {
        this.ws.close();
      } catch (_) {
        // ignore
      }
      this.ws = null;
    }
    this.connectDone = false;
  }

  private sendJson(obj: Record<string, Object>): void {
    if (this.ws === null) {
      return;
    }
    try {
      this.ws.send(JSON.stringify(obj));
    } catch (e) {
      Log.error(TAG, 'send fail %{public}s', JSON.stringify(e));
    }
  }

  private handleIncoming(text: string): void {
    try {
      const j = JSON.parse(text) as Record<string, Object>;
      const pingObj = j['ping'];
      if (pingObj !== undefined) {
        this.sendJson({ 'pong': pingObj as Record<string, Object> });
        return;
      }
      const pushObj = j['push'];
      if (pushObj !== undefined) {
        this.handlePush(pushObj as Record<string, Object>);
        return;
      }
      const cmdId = j['id'];
      const errObj = j['error'];
      if (cmdId !== undefined && typeof cmdId === 'number' && errObj !== undefined) {
        Log.error(TAG, 'server error cmd %{public}d %{public}s', cmdId, JSON.stringify(errObj));
        return;
      }
      if (cmdId === 1 && j['connect'] !== undefined && !this.connectDone) {
        this.connectDone = true;
        this.sendJson({
          'id': 2,
          'subscribe': {
            'channel': this.pendingChannel,
            'token': this.pendingSubToken
          } as Record<string, Object>
        } as Record<string, Object>);
        Log.info(TAG, 'subscribing %{public}s', this.pendingChannel);
        return;
      }
      if (cmdId === 2 && j['subscribe'] !== undefined) {
        Log.info(TAG, 'subscribe ack');
      }
    } catch (e) {
      Log.warn(TAG, 'parse frame %{public}s', JSON.stringify(e));
    }
  }

  private handlePush(push: Record<string, Object>): void {
    const ch = push['channel'];
    const channelStr = ch !== undefined ? `${ch}` : '';
    const pub = push['pub'] as Record<string, Object> | undefined;
    if (pub === undefined) {
      return;
    }
    const dataRaw = pub['data'];
    if (dataRaw === undefined) {
      return;
    }
    const decoded = CentrifugoClient.decodePubData(dataRaw);
    this.onPublication(channelStr, decoded);
  }

  /** data 可能是 JSON 字符串、对象或 Base64 */
  private static decodePubData(dataRaw: Object): string {
    if (typeof dataRaw === 'string') {
      const s = dataRaw as string;
      if (s.length > 0 && s.charAt(0) === '{') {
        return s;
      }
      try {
        const dec = new util.Base64Helper().decodeSync(s);
        return CentrifugoClient.uint8ToUtf8(new Uint8Array(dec));
      } catch (_) {
        return s;
      }
    }
    try {
      return JSON.stringify(dataRaw);
    } catch (_) {
      return '';
    }
  }

  private static bufferToUtf8(buf: ArrayBuffer): string {
    return CentrifugoClient.uint8ToUtf8(new Uint8Array(buf));
  }

  private static uint8ToUtf8(u8: Uint8Array): string {
    try {
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeWithStream(u8);
    } catch (_) {
      let s = '';
      for (let i = 0; i < u8.length; i++) {
        s += String.fromCharCode(u8[i]);
      }
      return s;
    }
  }
}
