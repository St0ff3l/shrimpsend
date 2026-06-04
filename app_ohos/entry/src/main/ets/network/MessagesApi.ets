import http from '@ohos.net.http';
import {
  apiUrl, checkAuthOk, HttpResult, requestWithAuthRetry
} from './HttpHelper';

export interface MessageEnvelope {
  type: string;
  payload: Object | string | number | boolean | null;
  fromDeviceId: string;
  ts: number;
  id?: number;
  toDeviceId?: string;
  threadKey?: string;
}

export class MessagesApi {
  static parseEnvelope(o: Record<string, Object>): MessageEnvelope {
    const idRaw = o['id'];
    let idNum: number | undefined = undefined;
    if (typeof idRaw === 'number') {
      idNum = idRaw;
    } else if (typeof idRaw === 'string') {
      const n = parseInt(idRaw, 10);
      if (!isNaN(n)) {
        idNum = n;
      }
    }
    const toRaw = o['toDeviceId'];
    const tkRaw = o['threadKey'];
    return {
      type: `${o['type']}`,
      payload: o['payload'] as Object,
      fromDeviceId: `${o['fromDeviceId']}`,
      ts: Number(o['ts']),
      id: idNum,
      toDeviceId: typeof toRaw === 'string' ? toRaw : undefined,
      threadKey: typeof tkRaw === 'string' ? tkRaw : undefined
    };
  }

  static async getHistory(limit: number = 50, before?: number, threadKey?: string): Promise<MessageEnvelope[]> {
    let q = `limit=${limit}`;
    if (before !== undefined && before > 0) {
      q += `&before=${before}`;
    }
    if (threadKey !== undefined && threadKey.length > 0) {
      q += `&threadKey=${encodeURIComponent(threadKey)}`;
    }
    const url = apiUrl(`/api/messages/history?${q}`);
    const res = await requestWithAuthRetry(http.RequestMethod.GET, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '加载历史失败');
    const arr = JSON.parse(res.body) as Object[];
    const out: MessageEnvelope[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i] as Record<string, Object>;
      out.push(MessagesApi.parseEnvelope(item));
    }
    return out;
  }

  static async sendMessage(data: MessageEnvelope): Promise<void> {
    const url = apiUrl('/api/messages/send');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify({ 'data': data }));
    await checkAuthOk(res, '发送失败');
    if (res.code !== 204) {
      throw new Error(res.body.length > 0 ? res.body : '发送失败');
    }
  }

  static async deleteMessage(messageId: number): Promise<void> {
    const url = apiUrl(`/api/messages/${messageId}`);
    const res = await requestWithAuthRetry(http.RequestMethod.DELETE, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '删除失败');
  }
}
