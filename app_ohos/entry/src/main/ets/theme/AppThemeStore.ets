import { PrefsKeys } from '../storage/PreferencesKeys';
import { prefGetString, prefSetString } from '../storage/PrefsHelper';

/** 简化版亮/暗色（对齐 Flutter theme_store 持久化） */
export class AppThemeStore {
  static async getChoice(): Promise<'system' | 'light' | 'dark'> {
    const v = await prefGetString(PrefsKeys.THEME_MODE, 'system');
    if (v === 'light' || v === 'dark' || v === 'system') {
      return v;
    }
    return 'system';
  }

  static async setChoice(c: 'system' | 'light' | 'dark'): Promise<void> {
    await prefSetString(PrefsKeys.THEME_MODE, c);
  }
}
