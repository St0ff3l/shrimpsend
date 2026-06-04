import deviceInfo from '@ohos.deviceInfo';
import util from '@ohos.util';
import { PrefsKeys } from './PreferencesKeys';
import { prefGetString, prefSetString } from './PrefsHelper';

function isLegacyDeviceId(id: string): boolean {
  return id.startsWith('flutter_');
}

async function generateDeviceId(): Promise<string> {
  const prefix = 'ohos';
  try {
    const odid = deviceInfo.ODID;
    if (odid !== undefined && odid !== null && odid.length > 0) {
      return `${prefix}_${odid}`;
    }
  } catch (_) {
    // ODID 可能需权限或未授权
  }
  return `${prefix}_uuid_${util.generateRandomUUID(true)}`;
}

async function generateDeviceName(): Promise<string> {
  try {
    const brand = deviceInfo.brand;
    const marketName = deviceInfo.marketName;
    const name = `${brand} ${marketName}`.trim();
    if (name.length > 0) {
      return name;
    }
  } catch (_) {
    // ignore
  }
  return 'HarmonyOS';
}

export async function getOrCreateDeviceId(): Promise<string> {
  let id = await prefGetString(PrefsKeys.DEVICE_ID, '');
  if (id.length === 0 || isLegacyDeviceId(id)) {
    id = await generateDeviceId();
    await prefSetString(PrefsKeys.DEVICE_ID, id);
  }
  return id;
}

export async function getDeviceName(): Promise<string> {
  let name = await prefGetString(PrefsKeys.DEVICE_NAME, '');
  if (name.length === 0 || name === 'Flutter') {
    name = await generateDeviceName();
    await prefSetString(PrefsKeys.DEVICE_NAME, name);
  }
  return name;
}

export async function setDeviceName(name: string): Promise<void> {
  await prefSetString(PrefsKeys.DEVICE_NAME, name);
}

export function getAuthPlatformLabel(): string {
  return 'ohos';
}
