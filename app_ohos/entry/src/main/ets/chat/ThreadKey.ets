/** Canonical thread keys — aligned with Flutter `thread_key.dart` / backend `ThreadKeyUtil`. */

export class ThreadKey {
  static readonly S3_VIRTUAL_DEVICE_ID: string = '__s3_cloud__';

  static accountPartLoggedIn(userId: string): string {
    return `u:${userId}`;
  }

  static accountPartOffline(offlineUserId: string): string {
    return `o:${offlineUserId}`;
  }

  static threadKeyOneToOne(accountPart: string, deviceIdA: string, deviceIdB: string): string {
    const a = deviceIdA <= deviceIdB ? deviceIdA : deviceIdB;
    const b = deviceIdA <= deviceIdB ? deviceIdB : deviceIdA;
    return `${accountPart}|d1:${a}|d2:${b}`;
  }

  static threadKeyS3Cloud(accountPart: string): string {
    return `${accountPart}|kind:s3_cloud`;
  }

  static threadKeyLegacyBroadcast(accountPart: string): string {
    return `${accountPart}|kind:legacy_broadcast`;
  }
}
