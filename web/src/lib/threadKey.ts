/** Same rules as `app/lib/chat/thread_key.dart` and backend `ThreadKeyUtil`. */

export const S3_VIRTUAL_DEVICE_ID = '__s3_cloud__';

const threadKindS3Cloud = 's3_cloud';
const threadKindLegacyBroadcast = 'legacy_broadcast';

export function accountPartLoggedIn(userId: string): string {
  return `u:${userId}`;
}

export function accountPartOffline(offlineUserId: string): string {
  return `o:${offlineUserId}`;
}

export function threadKeyOneToOne(accountPart: string, deviceIdA: string, deviceIdB: string): string {
  const a = deviceIdA <= deviceIdB ? deviceIdA : deviceIdB;
  const b = deviceIdA <= deviceIdB ? deviceIdB : deviceIdA;
  return `${accountPart}|d1:${a}|d2:${b}`;
}

export function threadKeyS3Cloud(accountPart: string): string {
  return `${accountPart}|kind:${threadKindS3Cloud}`;
}

export function threadKeyLegacyBroadcast(accountPart: string): string {
  return `${accountPart}|kind:${threadKindLegacyBroadcast}`;
}

export function threadKeyForPeerSelection(params: {
  accountPart: string;
  myDeviceId: string;
  selectedPeerId: string;
}): string {
  if (params.selectedPeerId === S3_VIRTUAL_DEVICE_ID) {
    return threadKeyS3Cloud(params.accountPart);
  }
  return threadKeyOneToOne(params.accountPart, params.myDeviceId, params.selectedPeerId);
}

/** Logged-in web / Flutter online: build outbound envelope fields from sidebar selection. */
export function outboundForWebChat(
  userId: string,
  selectedPeerId: string | null,
  myDeviceId: string,
): { threadKey: string; toDeviceId?: string } | null {
  if (!selectedPeerId) return null;
  const accountPart = accountPartLoggedIn(userId);
  if (selectedPeerId === S3_VIRTUAL_DEVICE_ID) {
    return { threadKey: threadKeyS3Cloud(accountPart) };
  }
  return {
    threadKey: threadKeyOneToOne(accountPart, myDeviceId, selectedPeerId),
    toDeviceId: selectedPeerId,
  };
}

export function threadKeyForS3WebPersist(
  userId: string,
  myDeviceId: string,
  toDeviceId: string | null | undefined,
): string {
  const ap = accountPartLoggedIn(userId);
  if (toDeviceId != null && toDeviceId !== '') {
    return threadKeyOneToOne(ap, myDeviceId, toDeviceId);
  }
  return threadKeyS3Cloud(ap);
}

export function deriveThreadKeyForStoredMessage(params: {
  accountPart: string;
  fromDeviceId: string;
  toDeviceId?: string | null;
  myDeviceId: string;
  explicitThreadKey?: string | null;
}): string {
  const { accountPart, fromDeviceId, myDeviceId, explicitThreadKey } = params;
  const to = params.toDeviceId;
  if (explicitThreadKey != null && explicitThreadKey.length > 0) {
    return explicitThreadKey;
  }
  if (
    to != null &&
    to !== '' &&
    to !== S3_VIRTUAL_DEVICE_ID &&
    fromDeviceId !== S3_VIRTUAL_DEVICE_ID
  ) {
    return threadKeyOneToOne(accountPart, fromDeviceId, to);
  }
  if (fromDeviceId !== myDeviceId) {
    return threadKeyOneToOne(accountPart, fromDeviceId, myDeviceId);
  }
  return threadKeyLegacyBroadcast(accountPart);
}
