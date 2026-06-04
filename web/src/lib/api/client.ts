import { logger } from '../logger';
import { getApiUrl } from '../config';

export { getApiUrl };

export const API_URL = getApiUrl();

export const TAG = 'api';

export class AuthError extends Error {
  constructor() {
    super('errors.authExpired');
    this.name = 'AuthError';
  }
}

export type AuthResponse = {
  accessToken: string;
  refreshToken: string;
  userId: string;
  expiresIn: number;
};

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('accessToken');
}

/** 供 Centrifugo connect proxy 鉴权：返回当前 accessToken，未登录时为 null */
export function getAccessToken(): string | null {
  return getToken();
}

/** 供 Web 端构建 user channel 名（user#<userId>），未登录时为 null */
export function getUserId(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('userId');
}

function getRefreshToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('refreshToken');
}

export function saveTokens(data: AuthResponse): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem('accessToken', data.accessToken);
  localStorage.setItem('refreshToken', data.refreshToken);
  localStorage.setItem('userId', data.userId);
}

export function clearStorage(): void {
  if (typeof window === 'undefined') return;
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('userId');
}

let onAuthExpired: (() => void) | null = null;
let onRefreshSuccess: ((data: AuthResponse) => void) | null = null;

/** 由应用注入：401 且 refresh 失败时调用，应执行 logout 并 router.replace('/login')，避免 window.location 导致 Back 回到未授权页。 */
export function setOnAuthExpired(fn: (() => void) | null): void {
  onAuthExpired = fn;
}

/** 由应用注入：refresh 成功后同步更新 React 状态（如 AuthContext），便于 WebSocket 等用新 token 重连。 */
export function setOnRefreshSuccess(fn: ((data: AuthResponse) => void) | null): void {
  onRefreshSuccess = fn;
}

function clearAuthAndRedirect(): void {
  if (typeof window === 'undefined') return;
  logger.warn(TAG, 'clearAuthAndRedirect');
  clearStorage();
  if (onAuthExpired) {
    onAuthExpired();
  } else {
    window.location.href = '/login';
  }
}

async function refreshTokensInternal(refreshToken: string): Promise<AuthResponse> {
  logger.info(TAG, 'refreshTokens');
  const res = await fetch(`${getApiUrl()}/api/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    logger.warn(TAG, 'refreshTokens failed', (err as { error?: string }).error);
    throw new Error((err as { error?: string }).error || 'errors.refreshFailed');
  }
  const data = await res.json() as AuthResponse;
  logger.info(TAG, 'refreshTokens success userId=', data.userId);
  return data;
}

/** 供 WebSocket 等场景在断开时尝试刷新 token 并触发重连（配合 setOnRefreshSuccess 更新 context 后 effect 会拿到新 token）。 */
export async function tryRefreshAndSave(): Promise<boolean> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) {
    logger.info(TAG, 'tryRefreshAndSave: no refreshToken');
    return false;
  }
  try {
    logger.info(TAG, 'tryRefreshAndSave: refreshing');
    const data = await refreshTokensInternal(refreshToken);
    saveTokens(data);
    onRefreshSuccess?.(data);
    logger.info(TAG, 'tryRefreshAndSave: success userId=', data.userId);
    return true;
  } catch (e) {
    logger.warn(TAG, 'tryRefreshAndSave: failed', e);
    return false;
  }
}

/** 服务端返回 401/403 时视为 token 失效，触发 refresh 重试；status 0 多为 CORS/opaque，也可能是未认证。 */
export function isAuthFailure(res: Response): boolean {
  if (res.status === 401 || res.status === 403) return true;
  if (res.status === 0 && !res.ok) return true;
  return false;
}

/** 带 401/403 自动刷新并重试的请求：先执行 fn，若遇认证失败则尝试 refresh 后重试一次，仍失败或 refresh 失败则清空登录并跳转登录页。 */
export async function withAuthRetry<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof AuthError) {
      logger.info(TAG, 'withAuthRetry: auth failed, attempting refresh');
      const ok = await tryRefreshAndSave();
      if (ok) {
        logger.info(TAG, 'withAuthRetry: refresh ok, retrying');
        return await fn();
      }
      clearAuthAndRedirect();
    }
    throw e;
  }
}
