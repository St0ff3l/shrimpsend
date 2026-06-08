'use client';

import { useEffect } from 'react';
import {
  getRefreshToken,
  maybeRefreshOnVisible,
  scheduleProactiveTokenRefresh,
  stopProactiveTokenRefresh,
} from '@/lib/api';

/**
 * 登录态下：过期前 proactive refresh + 标签页重新可见时补刷。
 */
export function useAuthSessionRefresh(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !getRefreshToken()) {
      stopProactiveTokenRefresh();
      return;
    }

    scheduleProactiveTokenRefresh();

    const onVisibilityChange = () => {
      if (document.visibilityState !== 'visible') return;
      void maybeRefreshOnVisible();
    };

    document.addEventListener('visibilitychange', onVisibilityChange);

    return () => {
      stopProactiveTokenRefresh();
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [enabled]);
}
