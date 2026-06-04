import { PrefsKeys } from '../storage/PreferencesKeys';
import { prefGetString, prefRemove, prefSetString } from '../storage/PrefsHelper';

export class ApiSession {
  private static accessToken: string = '';
  private static refreshToken: string = '';
  private static userId: string = '';
  private static onInvalidated: (() => Promise<void>) | null = null;

  static setOnSessionInvalidated(cb: (() => Promise<void>) | null): void {
    ApiSession.onInvalidated = cb;
  }

  static async invokeInvalidated(): Promise<void> {
    if (ApiSession.onInvalidated !== null) {
      await ApiSession.onInvalidated();
    }
  }

  static setTokens(access: string, refresh: string, uid: string): void {
    ApiSession.accessToken = access;
    ApiSession.refreshToken = refresh;
    ApiSession.userId = uid;
  }

  static getAccessToken(): string {
    return ApiSession.accessToken;
  }

  static getRefreshToken(): string {
    return ApiSession.refreshToken;
  }

  static getUserId(): string {
    return ApiSession.userId;
  }

  static hasLogin(): boolean {
    return ApiSession.accessToken.length > 0 && ApiSession.userId.length > 0;
  }

  static async loadFromStorage(): Promise<boolean> {
    const a = await prefGetString(PrefsKeys.ACCESS_TOKEN, '');
    const r = await prefGetString(PrefsKeys.REFRESH_TOKEN, '');
    const u = await prefGetString(PrefsKeys.USER_ID, '');
    if (a.length > 0 && u.length > 0) {
      ApiSession.accessToken = a;
      ApiSession.refreshToken = r;
      ApiSession.userId = u;
      return true;
    }
    return false;
  }

  static async persist(): Promise<void> {
    await prefSetString(PrefsKeys.ACCESS_TOKEN, ApiSession.accessToken);
    await prefSetString(PrefsKeys.REFRESH_TOKEN, ApiSession.refreshToken);
    await prefSetString(PrefsKeys.USER_ID, ApiSession.userId);
  }

  static async clear(): Promise<void> {
    ApiSession.accessToken = '';
    ApiSession.refreshToken = '';
    ApiSession.userId = '';
    await prefRemove(PrefsKeys.ACCESS_TOKEN);
    await prefRemove(PrefsKeys.REFRESH_TOKEN);
    await prefRemove(PrefsKeys.USER_ID);
  }
}
