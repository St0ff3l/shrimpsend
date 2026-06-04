'use client';

import { useEffect } from 'react';
import { usePathname } from 'next/navigation';

import { getOpenPanelClient } from '@/lib/openpanelClient';

/** App Router 下补充屏幕路径（SDK 自带 trackScreenViews 对 SPA 不完整时由 pathname 驱动）。 */
export function OpenPanelRouteTracker() {
  const pathname = usePathname();

  useEffect(() => {
    const op = getOpenPanelClient();
    if (!op || !pathname) return;
    op.screenView(pathname);
  }, [pathname]);

  return null;
}
