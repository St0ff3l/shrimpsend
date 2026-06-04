'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  loadSendShortcutMode,
  persistSendShortcutMode,
  SHORTCUTS_CHANGED_EVENT,
  type SendShortcutMode,
} from '@/lib/shortcutPreferences';

export function useSendShortcutMode(): [SendShortcutMode, (mode: SendShortcutMode) => void] {
  const [mode, setModeState] = useState<SendShortcutMode>(() => loadSendShortcutMode());

  useEffect(() => {
    const onChanged = (event: Event) => {
      const detail = (event as CustomEvent<{ key?: string; value?: SendShortcutMode }>).detail;
      if (detail?.key === 'send' && (detail.value === 'enter' || detail.value === 'modifier_enter')) {
        setModeState(detail.value);
        return;
      }
      setModeState(loadSendShortcutMode());
    };

    const onStorage = (event: StorageEvent) => {
      if (event.key === 'ultrasend_send_shortcut') {
        setModeState(loadSendShortcutMode());
      }
    };

    window.addEventListener(SHORTCUTS_CHANGED_EVENT, onChanged);
    window.addEventListener('storage', onStorage);
    return () => {
      window.removeEventListener(SHORTCUTS_CHANGED_EVENT, onChanged);
      window.removeEventListener('storage', onStorage);
    };
  }, []);

  const setMode = useCallback((next: SendShortcutMode) => {
    persistSendShortcutMode(next);
    setModeState(next);
  }, []);

  return [mode, setMode];
}
