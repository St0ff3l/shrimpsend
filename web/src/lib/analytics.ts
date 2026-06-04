import { getOpenPanelClient } from '@/lib/openpanelClient';

import { logger } from '@/lib/logger';

const TAG = 'analytics';

export function analyticsLengthBucket(len: number): string {
  if (len < 10) return 'lt_10';
  if (len < 50) return '10_50';
  if (len < 200) return '50_200';
  return 'gt_200';
}

export function analyticsSizeBucket(bytes: number): string {
  if (bytes < 0) return 'unknown';
  if (bytes < 1024 * 1024) return 'lt_1mb';
  if (bytes < 10 * 1024 * 1024) return '1mb_10mb';
  if (bytes < 100 * 1024 * 1024) return '10mb_100mb';
  if (bytes < 1024 * 1024 * 1024) return '100mb_1gb';
  return 'gt_1gb';
}

type TrackProps = Record<string, string | number | boolean | null | undefined>;

function cleanProps(props?: TrackProps): Record<string, string | number | boolean> {
  if (!props) return {};
  const out: Record<string, string | number | boolean> = {};
  for (const [k, v] of Object.entries(props)) {
    if (v === null || v === undefined) continue;
    if (typeof v === 'string' && v.length === 0) continue;
    out[k] = v;
  }
  return out;
}

/** OpenPanel 未初始化时静默跳过；不阻塞 UI */
export function analyticsTrack(name: string, props?: TrackProps): void {
  const op = getOpenPanelClient();
  if (!op) return;
  try {
    void op.track(name, cleanProps(props));
  } catch (e) {
    logger.warn(TAG, 'track failed', name, e);
  }
}
