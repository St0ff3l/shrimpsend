import { logger } from '../logger';
import { getApiUrl, TAG, AuthError, getToken, isAuthFailure, withAuthRetry } from './client';

export type DeviceDto = {
  /** 1–999 per-user display number from server; absent for LAN-only rows. */
  displayCode?: number | null;
  deviceId: string;
  name: string;
  platform?: string | null;
  lanHttpUrl?: string | null;
  lastSeen?: number | null;
  presenceStatus?: 'online' | 'offline' | string | null;
  presenceUpdatedAt?: number | null;
};

export async function registerDevice(deviceId: string, name: string, opts?: { lanHttpUrl?: string; platform?: string; sessionId?: string }): Promise<DeviceDto> {
  logger.info(TAG, 'registerDevice deviceId=', deviceId);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const res = await fetch(`${getApiUrl()}/api/devices`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({
        deviceId,
        name,
        lanHttpUrl: opts?.lanHttpUrl || undefined,
        platform: opts?.platform || undefined,
        sessionId: opts?.sessionId || undefined,
      }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'registerDevice failed', res.status);
      throw new Error('Failed to register device');
    }
    const dto = await res.json() as DeviceDto;
    logger.info(TAG, 'registerDevice success deviceId=', dto.deviceId);
    return dto;
  });
}

export async function updateDevicePresence(
  deviceId: string,
  body: { sessionId: string; status: 'online' | 'offline'; platform?: string },
  opts?: { keepalive?: boolean },
): Promise<DeviceDto> {
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const res = await fetch(`${getApiUrl()}/api/devices/${encodeURIComponent(deviceId)}/presence`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
      keepalive: opts?.keepalive,
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'updateDevicePresence failed', res.status);
      throw new Error('Failed to update device presence');
    }
    return res.json();
  });
}

export async function updateDevice(deviceId: string, data: { name?: string; lanHttpUrl?: string }): Promise<DeviceDto> {
  logger.info(TAG, 'updateDevice deviceId=', deviceId);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const res = await fetch(`${getApiUrl()}/api/devices/${encodeURIComponent(deviceId)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(data),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'updateDevice failed', res.status);
      throw new Error('Failed to update device');
    }
    return res.json();
  });
}

export async function deleteDevice(deviceId: string): Promise<void> {
  logger.info(TAG, 'deleteDevice deviceId=', deviceId);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const res = await fetch(`${getApiUrl()}/api/devices/${encodeURIComponent(deviceId)}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'deleteDevice failed', res.status);
      throw new Error('Failed to delete device');
    }
    logger.info(TAG, 'deleteDevice success deviceId=', deviceId);
  });
}

export async function listDevices(): Promise<DeviceDto[]> {
  logger.info(TAG, 'listDevices');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const res = await fetch(`${getApiUrl()}/api/devices`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'listDevices failed', res.status);
      throw new Error('Failed to list devices');
    }
    const list = await res.json() as DeviceDto[];
    logger.info(TAG, 'listDevices success count=', list.length);
    return list;
  });
}
