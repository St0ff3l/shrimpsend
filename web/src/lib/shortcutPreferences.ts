/** PC shortcut preferences. Align keys with Flutter `shortcut_preferences.dart`. */

const KEY_SEND_SHORTCUT = 'ultrasend_send_shortcut';

export type SendShortcutMode = 'enter' | 'modifier_enter';

export const SHORTCUTS_CHANGED_EVENT = 'ultrasend:shortcuts-changed';

export function loadSendShortcutMode(): SendShortcutMode {
  try {
    const v = localStorage.getItem(KEY_SEND_SHORTCUT);
    if (v === 'enter' || v === 'modifier_enter') return v;
    return 'modifier_enter';
  } catch {
    return 'modifier_enter';
  }
}

export function persistSendShortcutMode(mode: SendShortcutMode): void {
  try {
    localStorage.setItem(KEY_SEND_SHORTCUT, mode);
    window.dispatchEvent(
      new CustomEvent(SHORTCUTS_CHANGED_EVENT, {
        detail: { key: 'send', value: mode },
      }),
    );
  } catch {
    /* ignore */
  }
}

export function isMacPlatform(): boolean {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent;
  if (/Mac|iPhone|iPad|iPod/.test(ua)) return true;
  const platform = (navigator as Navigator & { userAgentData?: { platform?: string } }).userAgentData?.platform;
  return platform === 'macOS';
}
