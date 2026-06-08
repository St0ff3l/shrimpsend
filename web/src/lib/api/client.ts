import { logger } from '../logger';
import { getApiUrl } from '../config';
import {
  RefreshSessionOutcome,
  RefreshTokenError,
  SessionUnavailableError,
  classifyRefreshFailure,
  logRefreshFailure,
  outcomeFromRefreshFailure,
} from './refreshSession';

export { SessionUnavailableError, RefreshSessionOutcome } from './refreshSession';

export { getApiUrl };

export const API_URL = getApiUrl();

export const TAG = 'api';

/** 在 access token 过期前多久主动 refresh（默认 3 分钟）。 */
export const PROACTIVE_REFRESH_BUFFER_MS = 3 * 60 * 1000;

const DEFAULT_ACCESS_TTL_MS = 15 * 60 * 1000;
const KEY_ACCESS_TOKEN = 'accessToken';
const KEY_REFRESH_TOKEN = 'refreshToken';
const KEY_USER_ID = 'userId';
const KEY_ACCESS_TOKEN_EXPIRES_AT = 'accessTokenExpiresAt';

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
  return localStorage.getItem(KEY_ACCESS_TOKEN);
}

/** 供 Centrifugo connect proxy 鉴权：返回当前 accessToken，未登录时为 null */
export function getAccessToken(): string | null {
  return getToken();
}

/** 供 Web 端构建 user channel 名（user#<userId>），未登录时为 null */
export function getUserId(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(KEY_USER_ID);
}

export function getRefreshToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(KEY_REFRESH_TOKEN);
}

export function hasCompleteStoredSession(): boolean {
  const accessToken = getToken();
  const refreshToken = getRefreshToken();
  const userId = getUserId();
  return Boolean(
    accessToken && accessToken.length > 0
      && refreshToken && refreshToken.length > 0
      && userId && userId.length > 0,
  );
}

function parseAccessTokenExpiryMs(accessToken: string): number | null {
  try {
    const segment = accessToken.split('.')[1];
    if (!segment) return null;
    const payload = JSON.parse(atob(segment.replace(/-/g, '+').replace(/_/g, '/'))) as { exp?: number };
    if (typeof payload.exp === 'number') {
      return payload.exp * 1000;
    }
  } catch {
    // ignore malformed token
  }
  return null;
}

export function getAccessTokenExpiresAtMs(): number | null {
  if (typeof window === 'undefined') return null;
  const stored = localStorage.getItem(KEY_ACCESS_TOKEN_EXPIRES_AT);
  if (stored) {
    const parsed = Number(stored);
    if (!Number.isNaN(parsed) && parsed > 0) return parsed;
  }
  const accessToken = getToken();
  if (accessToken) {
    return parseAccessTokenExpiryMs(accessToken);
  }
  return null;
}

function setAccessTokenExpiresAtMs(expiresAtMs: number): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(KEY_ACCESS_TOKEN_EXPIRES_AT, String(expiresAtMs));
}

export function saveTokens(data: AuthResponse): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(KEY_ACCESS_TOKEN, data.accessToken);
  localStorage.setItem(KEY_REFRESH_TOKEN, data.refreshToken);
  localStorage.setItem(KEY_USER_ID, data.userId);
  const ttlMs = (data.expiresIn > 0 ? data.expiresIn : DEFAULT_ACCESS_TTL_MS / 1000) * 1000;
  setAccessTokenExpiresAtMs(Date.now() + ttlMs);
}

export function clearStorage(): void {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(KEY_ACCESS_TOKEN);
  localStorage.removeItem(KEY_REFRESH_TOKEN);
  localStorage.removeItem(KEY_USER_ID);
  localStorage.removeItem(KEY_ACCESS_TOKEN_EXPIRES_AT);
}

let onAuthExpired: (() => void) | null = null;
let onRefreshSuccess: ((data: AuthResponse) => void) | null = null;
let refreshInFlight: Promise<RefreshSessionOutcome> | null = null;
let proactiveRefreshTimer: ReturnType<typeof setTimeout> | null = null;

/** 由应用注入：401 且 refresh 永久失败时调用，应执行 logout 并 router.replace('/login')。 */
export function setOnAuthExpired(fn: (() => void) | null): void {
  onAuthExpired = fn;
}

/** 由应用注入：refresh 成功后同步更新 React 状态（如 AuthContext），便于 WebSocket 等用新 token 重连。 */
export function setOnRefreshSuccess(fn: ((data: AuthResponse) => void) | null): void {
  onRefreshSuccess = fn;
}

function clearAuthAndRedirect(reason: string): void {
  if (typeof window === 'undefined') return;
  logger.warn(TAG, 'clearAuthAndRedirect', reason);
  stopProactiveTokenRefresh();
  clearStorage();
  if (onAuthExpired) {
    onAuthExpired();
  } else {
    window.location.href = '/login';
  }
}

async function refreshTokensInternal(refreshToken: string): Promise<AuthResponse> {
  logger.info(TAG, 'refreshTokens');
  let res: Response;
  try {
    res = await fetch(`${getApiUrl()}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
  } catch (error) {
    logger.warn(TAG, 'refreshTokens network error', error);
    throw error;
  }
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const message = (err as { error?: string }).error || 'errors.refreshFailed';
    logger.warn(TAG, 'refreshTokens failed status=', res.status, message);
    throw new RefreshTokenError(message, res.status);
  }
  const data = await res.json() as AuthResponse;
  logger.info(TAG, 'refreshTokens success userId=', data.userId);
  return data;
}

async function tryRefreshStoredSession(attempt = 1): Promise<RefreshSessionOutcome> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) {
    logRefreshFailure(RefreshSessionOutcome.noRefreshToken, null, 'no refreshToken', undefined, attempt);
    return RefreshSessionOutcome.noRefreshToken;
  }

  try {
    const data = await refreshTokensInternal(refreshToken);
    saveTokens(data);
    onRefreshSuccess?.(data);
    logRefreshFailure(RefreshSessionOutcome.success, null, null, undefined, attempt);
    scheduleProactiveTokenRefresh();
    return RefreshSessionOutcome.success;
  } catch (error) {
    const httpStatus = error instanceof RefreshTokenError ? error.httpStatus : undefined;
    const failureKind = classifyRefreshFailure(error, httpStatus);
    const outcome = outcomeFromRefreshFailure(failureKind);
    logRefreshFailure(outcome, failureKind, error, httpStatus, attempt);
    return outcome;
  }
}

/** 单飞 refresh，避免并发请求轮换 token。 */
export async function refreshSingleFlight(attempt = 1): Promise<RefreshSessionOutcome> {
  if (refreshInFlight) {
    return refreshInFlight;
  }
  refreshInFlight = tryRefreshStoredSession(attempt).finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** 启动时 silent bootstrap：校验三件套并 refresh，网络抖动时重试。 */
export async function bootstrapStoredSession(): Promise<RefreshSessionOutcome> {
  if (!hasCompleteStoredSession()) {
    if (getToken() || getUserId()) {
      logger.warn(TAG, 'bootstrapStoredSession incomplete session, clearing');
      clearStorage();
    }
    return RefreshSessionOutcome.noRefreshToken;
  }

  const retryDelays = [0, 2000, 4000];
  let lastOutcome = RefreshSessionOutcome.transientFailure;

  for (let i = 0; i < retryDelays.length; i++) {
    if (retryDelays[i] > 0) {
      await sleep(retryDelays[i]);
      logger.info(TAG, `bootstrapStoredSession retry attempt=${i + 1}`);
    }
    lastOutcome = await refreshSingleFlight(i + 1);
    if (
      lastOutcome === RefreshSessionOutcome.success
      || lastOutcome === RefreshSessionOutcome.permanentFailure
      || lastOutcome === RefreshSessionOutcome.noRefreshToken
    ) {
      return lastOutcome;
    }
  }
  return lastOutcome;
}

/** 供 WebSocket 等场景在断开时尝试刷新 token 并触发重连。 */
export async function tryRefreshAndSave(): Promise<boolean> {
  const outcome = await refreshSingleFlight();
  return outcome === RefreshSessionOutcome.success;
}

export function stopProactiveTokenRefresh(): void {
  if (proactiveRefreshTimer != null) {
    clearTimeout(proactiveRefreshTimer);
    proactiveRefreshTimer = null;
  }
}

/** 在 access token 过期前主动 refresh；成功后自动重新调度。 */
export function scheduleProactiveTokenRefresh(): void {
  stopProactiveTokenRefresh();
  if (typeof window === 'undefined') return;
  if (!getRefreshToken()) return;

  const expiresAtMs = getAccessTokenExpiresAtMs();
  if (expiresAtMs == null) {
    const fallbackDelay = DEFAULT_ACCESS_TTL_MS - PROACTIVE_REFRESH_BUFFER_MS;
    proactiveRefreshTimer = setTimeout(() => {
      proactiveRefreshTimer = null;
      void runProactiveRefresh();
    }, Math.max(0, fallbackDelay));
    return;
  }

  const refreshAtMs = expiresAtMs - PROACTIVE_REFRESH_BUFFER_MS;
  const delay = Math.max(0, refreshAtMs - Date.now());
  proactiveRefreshTimer = setTimeout(() => {
    proactiveRefreshTimer = null;
    void runProactiveRefresh();
  }, delay);
}

async function runProactiveRefresh(): Promise<void> {
  if (!getRefreshToken()) return;
  logger.info(TAG, 'proactive token refresh');
  const outcome = await refreshSingleFlight();
  if (outcome === RefreshSessionOutcome.success) {
    scheduleProactiveTokenRefresh();
    return;
  }
  if (outcome === RefreshSessionOutcome.permanentFailure
    || outcome === RefreshSessionOutcome.noRefreshToken) {
    clearAuthAndRedirect('proactive_refresh_permanent_failure');
  }
}

/** 标签页重新可见或即将过期时补刷。 */
export async function maybeRefreshOnVisible(): Promise<boolean> {
  if (!getRefreshToken()) return false;
  const expiresAtMs = getAccessTokenExpiresAtMs();
  const needsRefresh = expiresAtMs == null
    || Date.now() >= expiresAtMs - PROACTIVE_REFRESH_BUFFER_MS;
  if (!needsRefresh) return false;
  logger.info(TAG, 'maybeRefreshOnVisible: refreshing');
  const outcome = await refreshSingleFlight();
  if (outcome === RefreshSessionOutcome.success) {
    scheduleProactiveTokenRefresh();
    return true;
  }
  return false;
}

/** 服务端返回 401 时视为 token 失效，触发 refresh 重试。403 为业务/权限错误，不触发 refresh。 */
export function isAuthFailure(res: Response): boolean {
  return res.status === 401;
}

/** 带 401 自动刷新并重试；网络抖动时保留会话，永久失效才登出。 */
export async function withAuthRetry<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof AuthError) {
      logger.info(TAG, 'withAuthRetry: auth failed, attempting refresh');
      const outcome = await refreshSingleFlight();
      if (outcome === RefreshSessionOutcome.success) {
        logger.info(TAG, 'withAuthRetry: refresh ok, retrying');
        try {
          return await fn();
        } catch (retryErr) {
          if (retryErr instanceof AuthError) {
            logger.warn(TAG, 'withAuthRetry: still 401 after refresh');
            clearAuthAndRedirect('still_401_after_refresh');
            throw new SessionUnavailableError('expired');
          }
          throw retryErr;
        }
      }
      if (outcome === RefreshSessionOutcome.transientFailure) {
        logger.warn(TAG, 'withAuthRetry: transient refresh failure');
        throw new SessionUnavailableError('transient');
      }
      clearAuthAndRedirect('refresh_permanent_failure');
      throw new SessionUnavailableError('expired');
    }
    throw e;
  }
}
