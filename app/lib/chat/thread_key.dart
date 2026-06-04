// Canonical thread key for message timelines (must match web + backend).
//
// Format:
// - Account: u:{userId} (logged in) or o:{offlineUserId} (offline).
// - 1:1 device: {account}|d1:{min}|d2:{max} (lexicographic min/max of the two device ids).
// - S3 cloud entry: {account}|kind:s3_cloud.
// - Legacy broadcast: {account}|kind:legacy_broadcast.

// Same value as s3VirtualDeviceId in device_provider.dart and S3_VIRTUAL_DEVICE_ID on web.
const kS3VirtualDeviceId = '__s3_cloud__';

const threadKindS3Cloud = 's3_cloud';
const threadKindLegacyBroadcast = 'legacy_broadcast';

String accountPartLoggedIn(String userId) => 'u:$userId';

String accountPartOffline(String offlineUserId) => 'o:$offlineUserId';

String threadKeyOneToOne(String accountPart, String deviceIdA, String deviceIdB) {
  final a = deviceIdA.compareTo(deviceIdB) <= 0 ? deviceIdA : deviceIdB;
  final b = deviceIdA.compareTo(deviceIdB) <= 0 ? deviceIdB : deviceIdA;
  return '$accountPart|d1:$a|d2:$b';
}

String threadKeyS3Cloud(String accountPart) =>
    '$accountPart|kind:$threadKindS3Cloud';

String threadKeyLegacyBroadcast(String accountPart) =>
    '$accountPart|kind:$threadKindLegacyBroadcast';

/// Thread for the current sidebar selection (peer or S3 virtual).
String threadKeyForPeerSelection({
  required String accountPart,
  required String myDeviceId,
  required String selectedPeerId,
}) {
  if (selectedPeerId == kS3VirtualDeviceId) {
    return threadKeyS3Cloud(accountPart);
  }
  return threadKeyOneToOne(accountPart, myDeviceId, selectedPeerId);
}

/// Derives [threadKey] for persistence when optional [explicitThreadKey] is absent.
///
/// - If [toDeviceId] is non-null and not S3 virtual: canonical pair (from, to).
/// - Else if [toDeviceId] is null and [fromDeviceId] != [myDeviceId]: treat as incoming
///   without explicit recipient → 1:1 with sender and this device.
/// - Else: legacy broadcast bucket (old outbound without [toDeviceId]).
String deriveThreadKeyForStoredMessage({
  required String accountPart,
  required String fromDeviceId,
  String? toDeviceId,
  required String myDeviceId,
  String? explicitThreadKey,
}) {
  if (explicitThreadKey != null && explicitThreadKey.isNotEmpty) {
    return explicitThreadKey;
  }
  final to = toDeviceId;
  if (to != null &&
      to.isNotEmpty &&
      to != kS3VirtualDeviceId &&
      fromDeviceId != kS3VirtualDeviceId) {
    return threadKeyOneToOne(accountPart, fromDeviceId, to);
  }
  if (fromDeviceId != myDeviceId) {
    return threadKeyOneToOne(accountPart, fromDeviceId, myDeviceId);
  }
  return threadKeyLegacyBroadcast(accountPart);
}
