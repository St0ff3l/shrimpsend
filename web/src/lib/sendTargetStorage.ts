/** Align with Flutter `device_provider.dart` preference keys. */

import { S3_VIRTUAL_DEVICE_ID } from '@/lib/threadKey';

const KEY_TARGETS = 'ultrasend_selected_targets';
const KEY_MODE = 'ultrasend_send_mode';
const KEY_MODE_BY_DEVICE = 'ultrasend_send_mode_by_device';
const KEY_PANEL_OPEN = 'ultrasend_device_panel_open';

export type WebSendMode = 'lan' | 'webrtc' | 's3';

export function loadSelectedTargets(): Set<string> {
  try {
    const raw = localStorage.getItem(KEY_TARGETS);
    if (!raw) return new Set();
    const arr = JSON.parse(raw) as unknown;
    if (!Array.isArray(arr)) return new Set();
    return new Set(arr.filter((x): x is string => typeof x === 'string'));
  } catch {
    return new Set();
  }
}

export function persistSelectedTargets(ids: Set<string>): void {
  try {
    localStorage.setItem(KEY_TARGETS, JSON.stringify([...ids]));
  } catch {
    /* ignore */
  }
}

function parseSendMode(value: unknown): WebSendMode | null {
  if (value === 'webrtc' || value === 's3' || value === 'lan') return value;
  if (value === 'nearby') return 'lan';
  return null;
}

export function loadSendModeMap(): Record<string, WebSendMode> {
  try {
    const raw = localStorage.getItem(KEY_MODE_BY_DEVICE);
    if (raw) {
      const obj = JSON.parse(raw) as unknown;
      if (obj && typeof obj === 'object') {
        const out: Record<string, WebSendMode> = {};
        for (const [deviceId, mode] of Object.entries(obj as Record<string, unknown>)) {
          const parsed = parseSendMode(mode);
          if (parsed) out[deviceId] = parsed;
        }
        return out;
      }
    }
  } catch {
    /* ignore */
  }

  // Legacy single global mode — cannot map to a device; treat as empty map.
  try {
    localStorage.removeItem(KEY_MODE);
  } catch {
    /* ignore */
  }
  return {};
}

export function loadSendModeForDevice(deviceId: string): WebSendMode {
  if (deviceId === S3_VIRTUAL_DEVICE_ID) return 's3';
  const map = loadSendModeMap();
  return map[deviceId] ?? 'lan';
}

export function persistSendModeForDevice(deviceId: string, mode: WebSendMode): void {
  if (deviceId === S3_VIRTUAL_DEVICE_ID) return;
  try {
    const map = loadSendModeMap();
    map[deviceId] = mode;
    localStorage.setItem(KEY_MODE_BY_DEVICE, JSON.stringify(map));
  } catch {
    /* ignore */
  }
}

/** @deprecated Use [loadSendModeForDevice] for chat sessions. */
export function loadSendMode(): WebSendMode {
  try {
    const v = localStorage.getItem(KEY_MODE);
    if (v === 'webrtc' || v === 's3' || v === 'lan') return v;
    if (v === 'nearby') return 'lan';
    return 'lan';
  } catch {
    return 'lan';
  }
}

/** @deprecated Use [persistSendModeForDevice] for chat sessions. */
export function persistSendMode(m: WebSendMode): void {
  try {
    localStorage.setItem(KEY_MODE, m);
  } catch {
    /* ignore */
  }
}

/** Desktop sidebar visible (only meaningful when viewport is md+). */
export function loadDesktopPanelOpen(): boolean {
  try {
    const v = localStorage.getItem(KEY_PANEL_OPEN);
    if (v === null) return true;
    return v === 'true';
  } catch {
    return true;
  }
}

export function persistDesktopPanelOpen(open: boolean): void {
  try {
    localStorage.setItem(KEY_PANEL_OPEN, open ? 'true' : 'false');
  } catch {
    /* ignore */
  }
}
