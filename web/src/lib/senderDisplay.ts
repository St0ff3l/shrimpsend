import type { DeviceDto } from '@/lib/api';

/** 会话列表旁名称：系统消息 / 已登记设备名 / 否则完整设备 ID（不截断） */
export function senderDisplayLabel(
  fromDeviceId: string,
  devices: DeviceDto[],
  t: (key: string) => string,
): string {
  if (fromDeviceId === 'system') return t('common.system');
  const d = devices.find((x) => x.deviceId === fromDeviceId);
  const n = d?.name?.trim();
  return n && n.length > 0 ? n : fromDeviceId;
}
