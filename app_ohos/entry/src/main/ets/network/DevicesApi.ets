import http from '@ohos.net.http';
import {
  apiUrl, checkAuthOk, requestWithAuthRetry
} from './HttpHelper';

export interface DeviceDto {
  deviceId: string;
  name: string;
  platform?: string;
  lanHttpUrl?: string;
  lastSeen?: number;
}

export class DevicesApi {
  static parse(j: Record<string, Object>): DeviceDto {
    const ls = j['lastSeen'];
    let lastSeen: number | undefined = undefined;
    if (typeof ls === 'number') {
      lastSeen = ls;
    }
    const dto: DeviceDto = {
      deviceId: `${j['deviceId']}`,
      name: `${j['name']}`,
      platform: j['platform'] !== undefined ? `${j['platform']}` : undefined,
      lanHttpUrl: j['lanHttpUrl'] !== undefined ? `${j['lanHttpUrl']}` : undefined,
      lastSeen: lastSeen
    };
    return dto;
  }

  static async list(): Promise<DeviceDto[]> {
    const url = apiUrl('/api/devices');
    const res = await requestWithAuthRetry(http.RequestMethod.GET, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '获取设备列表失败');
    const arr = JSON.parse(res.body) as Object[];
    const out: DeviceDto[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(DevicesApi.parse(arr[i] as Record<string, Object>));
    }
    return out;
  }

  static async register(deviceId: string, name: string, platform?: string, lanHttpUrl?: string): Promise<DeviceDto> {
    const body: Record<string, Object> = {
      'deviceId': deviceId,
      'name': name
    };
    if (platform !== undefined) {
      body['platform'] = platform;
    }
    if (lanHttpUrl !== undefined) {
      body['lanHttpUrl'] = lanHttpUrl;
    }
    const url = apiUrl('/api/devices');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify(body));
    await checkAuthOk(res, '设备注册失败');
    const obj = JSON.parse(res.body) as Record<string, Object>;
    return DevicesApi.parse(obj);
  }

  static async update(deviceId: string, name?: string, lanHttpUrl?: string): Promise<DeviceDto> {
    const enc = encodeURIComponent(deviceId);
    const body: Record<string, Object> = {};
    if (name !== undefined) {
      body['name'] = name;
    }
    if (lanHttpUrl !== undefined) {
      body['lanHttpUrl'] = lanHttpUrl;
    }
    const url = apiUrl(`/api/devices/${enc}`);
    const res = await requestWithAuthRetry(http.RequestMethod.PUT, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify(body));
    await checkAuthOk(res, '更新设备失败');
    const obj = JSON.parse(res.body) as Record<string, Object>;
    return DevicesApi.parse(obj);
  }

  static async delete(deviceId: string): Promise<void> {
    const enc = encodeURIComponent(deviceId);
    const url = apiUrl(`/api/devices/${enc}`);
    const res = await requestWithAuthRetry(http.RequestMethod.DELETE, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '删除设备失败');
  }
}
