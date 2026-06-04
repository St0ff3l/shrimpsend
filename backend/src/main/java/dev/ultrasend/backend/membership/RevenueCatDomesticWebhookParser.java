package dev.ultrasend.backend.membership;

import java.util.Map;

/**
 * Parses RevenueCat webhook bodies for the domestic (lifetime IAP) cluster.
 * Supports nested {@code event} objects (RC v2) and legacy flat payloads.
 */
public final class RevenueCatDomesticWebhookParser {

    public record Parsed(String transactionId, String productId, String appUserId, String eventType) {}

    private RevenueCatDomesticWebhookParser() {}

    @SuppressWarnings("unchecked")
    public static Parsed parse(Map<String, Object> payload) {
        Map<String, Object> event = payload.containsKey("event") && payload.get("event") instanceof Map
                ? (Map<String, Object>) payload.get("event")
                : payload;

        String transactionId = asString(event.get("transaction_id"));
        String productId = asString(event.get("product_id"));
        String appUserId = asString(event.get("app_user_id"));
        if (appUserId == null || appUserId.isBlank()) {
            appUserId = asString(payload.get("app_user_id"));
        }

        String eventType = asString(event.get("type"));
        if (eventType == null) {
            Object legacyEvent = payload.get("event");
            if (!(legacyEvent instanceof Map)) {
                eventType = asString(legacyEvent);
            }
        }

        return new Parsed(transactionId, productId, appUserId, eventType);
    }

    private static String asString(Object v) {
        return v == null ? null : String.valueOf(v);
    }
}
