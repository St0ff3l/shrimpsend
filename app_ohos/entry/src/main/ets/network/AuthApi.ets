import http from '@ohos.net.http';
import { Env } from '../common/Env';
import { Log } from '../common/Logger';
import { ApiSession } from './ApiSession';
import {
  apiUrl,
  parseErrorBody,
  requestJsonOnly,
  requestWithAuthRetry
} from './HttpHelper';

const TAG = 'AuthApi';

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  userId: string;
}

function parseAuth(j: Record<string, Object>): AuthResponse {
  return {
    accessToken: `${j['accessToken']}`,
    refreshToken: `${j['refreshToken']}`,
    userId: `${j['userId']}`
  };
}

export class AuthApi {
  static async login(email: string, password: string, deviceId: string, platform: string): Promise<AuthResponse> {
    const url = apiUrl('/api/auth/login');
    const body = JSON.stringify({
      'email': email.trim().toLowerCase(),
      'password': password,
      'deviceId': deviceId,
      'platform': platform
    });
    const r = await requestJsonOnly(http.RequestMethod.POST, url, body);
    if (r.code !== 200) {
      throw new Error(parseErrorBody(r.body, `登录失败 (${r.code})`));
    }
    const obj = JSON.parse(r.body) as Record<string, Object>;
    return parseAuth(obj);
  }

  static async loginByCode(email: string, code: string, deviceId: string, platform: string): Promise<AuthResponse> {
    const url = apiUrl('/api/auth/login-by-code');
    const body = JSON.stringify({
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'deviceId': deviceId,
      'platform': platform
    });
    const r = await requestJsonOnly(http.RequestMethod.POST, url, body);
    if (r.code !== 200) {
      throw new Error(parseErrorBody(r.body, `验证码登录失败 (${r.code})`));
    }
    const obj = JSON.parse(r.body) as Record<string, Object>;
    return parseAuth(obj);
  }

  static async register(
    email: string,
    password: string,
    code: string,
    deviceId: string,
    platform: string,
    username?: string
  ): Promise<AuthResponse> {
    const url = apiUrl('/api/auth/register');
    const obj: Record<string, Object> = {
      'email': email.trim().toLowerCase(),
      'password': password,
      'code': code,
      'deviceId': deviceId,
      'platform': platform
    };
    if (username !== undefined && username.trim().length > 0) {
      obj['username'] = username.trim();
    }
    const r = await requestJsonOnly(http.RequestMethod.POST, url, JSON.stringify(obj));
    if (r.code !== 200) {
      throw new Error(parseErrorBody(r.body, `注册失败 (${r.code})`));
    }
    const ro = JSON.parse(r.body) as Record<string, Object>;
    return parseAuth(ro);
  }

  static async sendVerificationCode(email: string, type?: string, deviceId?: string, platform?: string): Promise<void> {
    const url = apiUrl('/api/auth/send-code');
    const obj: Record<string, Object> = {
      'email': email.trim().toLowerCase()
    };
    if (type !== undefined && type.length > 0) {
      obj['type'] = type;
    }
    if (deviceId !== undefined && deviceId.length > 0) {
      obj['deviceId'] = deviceId;
    }
    if (platform !== undefined && platform.length > 0) {
      obj['platform'] = platform;
    }
    const r = await requestJsonOnly(http.RequestMethod.POST, url, JSON.stringify(obj));
    if (r.code !== 200) {
      throw new Error(parseErrorBody(r.body, `发送验证码失败 (${r.code})`));
    }
  }

  static async refreshTokens(refreshToken: string): Promise<AuthResponse> {
    const url = apiUrl('/api/auth/refresh');
    const r = await requestJsonOnly(http.RequestMethod.POST, url, JSON.stringify({ 'refreshToken': refreshToken }));
    if (r.code !== 200) {
      throw new Error(parseErrorBody(r.body, '刷新失败'));
    }
    const obj = JSON.parse(r.body) as Record<string, Object>;
    return parseAuth(obj);
  }

  /** @returns 是否刷新成功并已写入 ApiSession */
  static async tryRefreshAndPersist(): Promise<boolean> {
    const rt = ApiSession.getRefreshToken();
    if (rt.length === 0) {
      Log.warn(TAG, 'no refresh token');
      return false;
    }
    try {
      const auth = await AuthApi.refreshTokens(rt);
      ApiSession.setTokens(auth.accessToken, auth.refreshToken, auth.userId);
      await ApiSession.persist();
      Log.info(TAG, 'refresh ok');
      return true;
    } catch (e) {
      Log.warn(TAG, 'refresh failed %{public}s', JSON.stringify(e));
      return false;
    }
  }

  static async logout(deviceId: string): Promise<void> {
    const url = apiUrl('/api/auth/logout');
    try {
      const r = await requestWithAuthRetry(http.RequestMethod.POST, url, { 'Content-Type': 'application/json' },
        JSON.stringify({ 'deviceId': deviceId }));
      Log.info(TAG, 'logout status %{public}d', r.code);
    } catch (_) {
      // ignore
    }
  }

  static applyAuthResponse(auth: AuthResponse): Promise<void> {
    ApiSession.setTokens(auth.accessToken, auth.refreshToken, auth.userId);
    return ApiSession.persist();
  }
}
