import http from '@ohos.net.http';
import { apiUrl } from './HttpHelper';

export interface UpdateInfo {
  version: string;
  buildNumber: number;
  downloadUrl: string;
  releaseNotes: string;
  iosStoreUrl: string;
  releasedAt?: string;
}

export class AppVersionApi {
  static parse(j: Record<string, Object>): UpdateInfo | null {
    const version = j['version'];
    const buildNumber = j['buildNumber'];
    const downloadUrl = j['downloadUrl'];
    if (version === undefined || buildNumber === undefined) {
      return null;
    }
    let bn = 0;
    if (typeof buildNumber === 'number') {
      bn = buildNumber;
    } else {
      bn = parseInt(`${buildNumber}`, 10);
    }
    return {
      version: `${version}`,
      buildNumber: bn,
      downloadUrl: downloadUrl !== undefined ? `${downloadUrl}` : '',
      releaseNotes: j['releaseNotes'] !== undefined ? `${j['releaseNotes']}` : '',
      iosStoreUrl: j['iosStoreUrl'] !== undefined ? `${j['iosStoreUrl']}` : '',
      releasedAt: j['releasedAt'] !== undefined ? `${j['releasedAt']}` : undefined
    };
  }

  static async fetchVersionHistory(): Promise<UpdateInfo[]> {
    const url = apiUrl('/api/app/versions');
    try {
      const req = http.createHttp();
      const res = await new Promise<http.HttpResponse>((resolve, reject) => {
        req.request(url, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 10000,
          readTimeout: 10000
        }, (err: Error | null, data: http.HttpResponse | null) => {
          req.destroy();
          if (err != null || data === null) {
            reject(err ?? new Error('no data'));
            return;
          }
          resolve(data);
        });
      });
      if (res.responseCode !== 200) {
        return [];
      }
      const body = typeof res.result === 'string' ? res.result : '';
      if (body.length === 0 || !body.trim().startsWith('[')) {
        return [];
      }
      const arr = JSON.parse(body) as Object[];
      const out: UpdateInfo[] = [];
      for (let i = 0; i < arr.length; i++) {
        const info = AppVersionApi.parse(arr[i] as Record<string, Object>);
        if (info !== null) {
          out.push(info);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /** 兼容 Flutter AppUpdateService 检查路径（若后端提供） */
  static async checkLatestJson(): Promise<Record<string, Object> | null> {
    const url = apiUrl('/api/app/latest.json');
    try {
      const req = http.createHttp();
      const res = await new Promise<http.HttpResponse>((resolve, reject) => {
        req.request(url, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 10000,
          readTimeout: 10000
        }, (err: Error | null, data: http.HttpResponse | null) => {
          req.destroy();
          if (err != null || data === null) {
            reject(err ?? new Error('no data'));
            return;
          }
          resolve(data);
        });
      });
      if (res.responseCode !== 200) {
        return null;
      }
      const body = typeof res.result === 'string' ? res.result : '';
      if (body.length === 0) {
        return null;
      }
      return JSON.parse(body) as Record<string, Object>;
    } catch (_) {
      return null;
    }
  }
}
