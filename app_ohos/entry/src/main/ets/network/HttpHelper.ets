import http from '@ohos.net.http';
import { Env } from '../common/Env';
import { Log } from '../common/Logger';
import { ApiSession } from './ApiSession';

const TAG = 'Http';

/** 由入口注入，避免 HttpHelper ↔ AuthApi 循环依赖 */
let refreshTokenHandler: (() => Promise<boolean>) | null = null;

export function setRefreshTokenHandler(handler: (() => Promise<boolean>) | null): void {
  refreshTokenHandler = handler;
}

/** ArkTS 要求必须继承 Error 类 */
export class AuthHttpError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export interface HttpResult {
  code: number;
  body: string;
}

function mergeHeaders(base: Record<string, string>, auth: boolean): Record<string, string> {
  const h: Record<string, string> = {};
  const keys = Object.keys(base);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    h[k] = base[k];
  }
  if (auth) {
    const t = ApiSession.getAccessToken();
    if (t.length > 0) {
      h['Authorization'] = `Bearer ${t}`;
    }
  }
  return h;
}

async function rawRequest(
  method: http.RequestMethod,
  url: string,
  headers: Record<string, string>,
  extraData?: string
): Promise<HttpResult> {
  return new Promise<HttpResult>((resolve, reject) => {
    const req = http.createHttp();
    req.request(url, {
      method,
      header: headers,
      extraData: extraData,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 60000,
      readTimeout: 120000
    }, (err: Error | null, data: http.HttpResponse | null) => {
      if (err != null) {
        req.destroy();
        reject(err);
        return;
      }
      if (data === null) {
        req.destroy();
        reject(new Error('empty http response'));
        return;
      }
      const code = data.responseCode;
      let body = '';
      const result = data.result;
      if (typeof result === 'string') {
        body = result;
      } else {
        body = '';
      }
      req.destroy();
      resolve({ code: code, body: body });
    });
  });
}

export function apiUrl(path: string): string {
  return `${Env.apiUrl}${path}`;
}

export function parseErrorBody(body: string, fallback: string): string {
  if (body.length === 0) {
    return fallback;
  }
  try {
    const obj = JSON.parse(body) as Record<string, Object>;
    const e = obj['error'];
    if (e !== undefined && e !== null) {
      return `${e}`;
    }
  } catch (_) {
    // ignore
  }
  return fallback;
}

/** 401 时刷新并重试一次；仍失败则清会话 */
export async function requestWithAuthRetry(
  method: http.RequestMethod,
  url: string,
  headersNoAuth: Record<string, string>,
  body?: string
): Promise<HttpResult> {
  const first = await rawRequest(method, url, mergeHeaders(headersNoAuth, true), body);
  if (first.code !== 401) {
    return first;
  }
  Log.info(TAG, '401, try refresh');
  const ok = refreshTokenHandler !== null ? await refreshTokenHandler() : false;
  if (!ok) {
    await ApiSession.clear();
    await ApiSession.invokeInvalidated();
    throw new AuthHttpError(parseErrorBody(first.body, '登录已过期，请重新登录'));
  }
  const second = await rawRequest(method, url, mergeHeaders(headersNoAuth, true), body);
  if (second.code === 401) {
    await ApiSession.clear();
    await ApiSession.invokeInvalidated();
    throw new AuthHttpError(parseErrorBody(second.body, '登录已过期，请重新登录'));
  }
  return second;
}

export async function requestJsonOnly(
  method: http.RequestMethod,
  url: string,
  body?: string
): Promise<HttpResult> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json'
  };
  return await rawRequest(method, url, headers, body);
}

export async function checkAuthOk(res: HttpResult, fallback: string): Promise<void> {
  if (res.code === 401) {
    throw new AuthHttpError(parseErrorBody(res.body, '登录已过期，请重新登录'));
  }
  if (res.code < 200 || res.code >= 300) {
    throw new Error(parseErrorBody(res.body, fallback));
  }
}
