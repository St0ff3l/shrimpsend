import http from '@ohos.net.http';
import {
  apiUrl,
  checkAuthOk,
  requestWithAuthRetry
} from './HttpHelper';

export interface CentrifugoTokenBundle {
  connectionToken: string;
  subscriptionToken: string;
  channel: string;
}

export class CentrifugoHttpApi {
  static async getToken(): Promise<CentrifugoTokenBundle> {
    const url = apiUrl('/api/centrifugo/token');
    const res = await requestWithAuthRetry(http.RequestMethod.GET, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '获取连接凭证失败');
    const j = JSON.parse(res.body) as Record<string, Object>;
    return {
      connectionToken: `${j['connectionToken']}`,
      subscriptionToken: `${j['subscriptionToken']}`,
      channel: `${j['channel']}`
    };
  }
}
