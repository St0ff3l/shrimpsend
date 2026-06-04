import { Env } from '../common/Env';
import { CentrifugoHttpApi } from '../network/CentrifugoHttpApi';
import { CentrifugoClient } from './CentrifugoClient';

/** 管理 Centrifugo 连接生命周期，供聊天页使用 */
export class RealtimeHub {
  private static client: CentrifugoClient | null = null;

  static async connect(onPublication: (channel: string, dataUtf8: string) => void): Promise<void> {
    RealtimeHub.disconnect();
    const bundle = await CentrifugoHttpApi.getToken();
    const c = new CentrifugoClient();
    RealtimeHub.client = c;
    c.connect(
      Env.centrifugoWs,
      bundle.connectionToken,
      bundle.channel,
      bundle.subscriptionToken,
      onPublication
    );
  }

  static disconnect(): void {
    if (RealtimeHub.client !== null) {
      RealtimeHub.client.disconnect();
      RealtimeHub.client = null;
    }
  }
}
