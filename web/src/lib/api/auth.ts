import { logger } from '../logger';
import { getOrCreateDeviceId } from '../deviceId';
import { getApiUrl, TAG, getToken } from './client';
import type { AuthResponse } from './client';

export async function login(email: string, password: string): Promise<AuthResponse> {
  logger.info(TAG, 'login attempt email=', email.trim().toLowerCase());
  const deviceId = getOrCreateDeviceId();
  const res = await fetch(`${getApiUrl()}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email.trim().toLowerCase(),
      password,
      deviceId,
      platform: 'web',
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: string }).error || 'errors.loginFailed';
    logger.warn(TAG, 'login failed', msg);
    throw new Error(msg);
  }
  const data = await res.json() as AuthResponse;
  logger.info(TAG, 'login success userId=', data.userId);
  return data;
}

export async function sendVerificationCode(
  email: string,
  opts?: { type?: string },
): Promise<void> {
  logger.info(TAG, 'sendCode email=', email.trim().toLowerCase());
  const body: Record<string, string> = { email: email.trim().toLowerCase() };
  if (opts?.type) body.type = opts.type;
  if (opts?.type === 'LOGIN') {
    body.deviceId = getOrCreateDeviceId();
    body.platform = 'web';
  }
  const res = await fetch(`${getApiUrl()}/api/auth/send-code`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: string }).error || 'errors.sendCodeFailed';
    logger.warn(TAG, 'sendCode failed', msg);
    throw new Error(msg);
  }
  logger.info(TAG, 'sendCode success');
}

export async function register(email: string, password: string, code: string, username?: string): Promise<AuthResponse> {
  logger.info(TAG, 'register attempt email=', email.trim().toLowerCase());
  const deviceId = getOrCreateDeviceId();
  const res = await fetch(`${getApiUrl()}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email.trim().toLowerCase(),
      password,
      code,
      username: username?.trim() || undefined,
      deviceId,
      platform: 'web',
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: string }).error || 'errors.registerFailed';
    logger.warn(TAG, 'register failed', msg);
    throw new Error(msg);
  }
  const data = await res.json() as AuthResponse;
  logger.info(TAG, 'register success userId=', data.userId);
  return data;
}

export type QrStatusResponse = {
  status: string;
  accessToken?: string;
  refreshToken?: string;
  userId?: string;
  expiresIn?: number;
};

export async function createQrSession(): Promise<string> {
  logger.info(TAG, 'createQrSession');
  const res = await fetch(`${getApiUrl()}/api/auth/qr/create`, { method: 'POST' });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: string }).error || 'errors.qrCreateFailed';
    logger.warn(TAG, 'createQrSession failed', msg);
    throw new Error(msg);
  }
  const data = await res.json() as { sessionId: string };
  logger.info(TAG, 'createQrSession success sessionId=', data.sessionId);
  return data.sessionId;
}

export async function getQrStatus(sessionId: string): Promise<QrStatusResponse> {
  const params = new URLSearchParams({
    deviceId: getOrCreateDeviceId(),
    platform: 'web',
  });
  const res = await fetch(`${getApiUrl()}/api/auth/qr/status/${sessionId}?${params}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as { error?: string }).error || 'errors.qrQueryFailed');
  }
  return await res.json() as QrStatusResponse;
}

export async function apiLogout(deviceId?: string): Promise<void> {
  logger.info(TAG, 'logout deviceId=', deviceId);
  const token = getToken();
  if (!token) return;
  try {
    await fetch(`${getApiUrl()}/api/auth/logout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ deviceId: deviceId || undefined }),
    });
    logger.info(TAG, 'logout success');
  } catch (e) {
    logger.warn(TAG, 'logout failed', e);
  }
}

export async function refreshTokens(refreshToken: string): Promise<AuthResponse> {
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
