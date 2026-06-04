'use client';

import { useEffect, useState } from 'react';
import {
  DEVICE_LIST_PANEL_MIN_WIDTH,
  resolveDeviceListPanelWidth,
} from '@/lib/deviceListPanelWidth';

/** Subscribes to viewport resize and returns the dynamic device-list panel width. */
export function useDeviceListPanelWidth(): number {
  const [width, setWidth] = useState(DEVICE_LIST_PANEL_MIN_WIDTH);

  useEffect(() => {
    const update = () => setWidth(resolveDeviceListPanelWidth(window.innerWidth));
    update();
    window.addEventListener('resize', update);
    return () => window.removeEventListener('resize', update);
  }, []);

  return width;
}
