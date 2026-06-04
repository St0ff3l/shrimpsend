import { logger } from '../logger';
import { getApiUrl, TAG, AuthError, getToken, isAuthFailure, withAuthRetry } from './client';

export type UserProfile = {
  userId: string;
  email: string;
  username: string;
};

export async function fetchUserProfile(): Promise<UserProfile> {
  logger.info(TAG, 'fetchUserProfile');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/user/profile`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const msg = (err as { error?: string }).error || 'errors.profileFetchFailed';
      logger.warn(TAG, 'fetchUserProfile failed', msg);
      throw new Error(msg);
    }
    const data = await res.json() as UserProfile;
    logger.info(TAG, 'fetchUserProfile success userId=', data.userId);
    return data;
  });
}

export async function sendChangePasswordCode(): Promise<void> {
  logger.info(TAG, 'sendChangePasswordCode');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/user/send-change-password-code`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const msg = (err as { error?: string }).error || 'errors.sendCodeFailed';
      logger.warn(TAG, 'sendChangePasswordCode failed', msg);
      throw new Error(msg);
    }
    logger.info(TAG, 'sendChangePasswordCode success');
  });
}

export async function changePassword(code: string, newPassword: string): Promise<void> {
  logger.info(TAG, 'changePassword');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/user/change-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ code, newPassword }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const msg = (err as { error?: string }).error || 'errors.changePasswordFailed';
      logger.warn(TAG, 'changePassword failed', msg);
      throw new Error(msg);
    }
    logger.info(TAG, 'changePassword success');
  });
}

export async function sendDeleteAccountCode(): Promise<void> {
  logger.info(TAG, 'sendDeleteAccountCode');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/user/send-delete-code`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const msg = (err as { error?: string }).error || 'errors.sendCodeFailed';
      logger.warn(TAG, 'sendDeleteAccountCode failed', msg);
      throw new Error(msg);
    }
    logger.info(TAG, 'sendDeleteAccountCode success');
  });
}

export async function confirmDeleteAccount(code: string): Promise<void> {
  logger.info(TAG, 'confirmDeleteAccount');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/user/confirm-delete-account`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ code }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const msg = (err as { error?: string }).error || 'errors.deleteAccountFailed';
      logger.warn(TAG, 'confirmDeleteAccount failed', msg);
      throw new Error(msg);
    }
    logger.info(TAG, 'confirmDeleteAccount success');
  });
}
