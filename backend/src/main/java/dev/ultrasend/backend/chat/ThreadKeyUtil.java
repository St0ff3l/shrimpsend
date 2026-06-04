package dev.ultrasend.backend.chat;

import java.util.Objects;

/**
 * Canonical thread keys — must match {@code app/lib/chat/thread_key.dart} and {@code web/src/lib/threadKey.ts}.
 */
public final class ThreadKeyUtil {

    public static final String S3_VIRTUAL_DEVICE_ID = "__s3_cloud__";
    private static final String KIND_S3_CLOUD = "s3_cloud";
    private static final String KIND_LEGACY_BROADCAST = "legacy_broadcast";

    private ThreadKeyUtil() {
    }

    public static String accountPartLoggedIn(String userId) {
        return "u:" + userId;
    }

    public static String accountPartOffline(String offlineUserId) {
        return "o:" + offlineUserId;
    }

    public static String threadKeyOneToOne(String accountPart, String deviceIdA, String deviceIdB) {
        String a = deviceIdA.compareTo(deviceIdB) <= 0 ? deviceIdA : deviceIdB;
        String b = deviceIdA.compareTo(deviceIdB) <= 0 ? deviceIdB : deviceIdA;
        return accountPart + "|d1:" + a + "|d2:" + b;
    }

    public static String threadKeyS3Cloud(String accountPart) {
        return accountPart + "|kind:" + KIND_S3_CLOUD;
    }

    public static String threadKeyLegacyBroadcast(String accountPart) {
        return accountPart + "|kind:" + KIND_LEGACY_BROADCAST;
    }

    public static String threadKeyForPeerSelection(String accountPart, String myDeviceId, String selectedPeerId) {
        if (Objects.equals(selectedPeerId, S3_VIRTUAL_DEVICE_ID)) {
            return threadKeyS3Cloud(accountPart);
        }
        return threadKeyOneToOne(accountPart, myDeviceId, selectedPeerId);
    }

    /**
     * Fills missing threadKey on inbound payloads using the same rules as mobile/web clients.
     *
     * @param userId        authenticated user id string (for account part u:{id})
     * @param fromDeviceId  envelope fromDeviceId
     * @param toDeviceId    envelope toDeviceId (nullable)
     * @param myDeviceId    optional current device id for inference when to is null
     */
    public static String deriveThreadKeyForStoredMessage(
            String userId,
            String fromDeviceId,
            String toDeviceId,
            String myDeviceId,
            String explicitThreadKey) {
        String accountPart = accountPartLoggedIn(userId);
        if (explicitThreadKey != null && !explicitThreadKey.isBlank()) {
            return explicitThreadKey;
        }
        if (toDeviceId != null
                && !toDeviceId.isEmpty()
                && !S3_VIRTUAL_DEVICE_ID.equals(toDeviceId)
                && !S3_VIRTUAL_DEVICE_ID.equals(fromDeviceId)) {
            return threadKeyOneToOne(accountPart, fromDeviceId, toDeviceId);
        }
        if (myDeviceId != null
                && !myDeviceId.isBlank()
                && !Objects.equals(fromDeviceId, myDeviceId)) {
            return threadKeyOneToOne(accountPart, fromDeviceId, myDeviceId);
        }
        return threadKeyLegacyBroadcast(accountPart);
    }
}
