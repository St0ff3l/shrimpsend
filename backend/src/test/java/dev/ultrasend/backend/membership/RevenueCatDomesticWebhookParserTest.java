package dev.ultrasend.backend.membership;

import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class RevenueCatDomesticWebhookParserTest {

    @Test
    void parse_nestedEventObject() {
        Map<String, Object> event = new HashMap<>();
        event.put("id", "evt-1");
        event.put("type", "NON_RENEWING_PURCHASE");
        event.put("app_user_id", "123");
        event.put("product_id", "ultrasend_mini_lifetime");
        event.put("transaction_id", "txn-abc");
        Map<String, Object> payload = Map.of("event", event);

        RevenueCatDomesticWebhookParser.Parsed parsed =
                RevenueCatDomesticWebhookParser.parse(payload);

        assertEquals("txn-abc", parsed.transactionId());
        assertEquals("ultrasend_mini_lifetime", parsed.productId());
        assertEquals("123", parsed.appUserId());
        assertEquals("NON_RENEWING_PURCHASE", parsed.eventType());
    }

    @Test
    void parse_legacyFlatPayload() {
        Map<String, Object> payload = new HashMap<>();
        payload.put("transaction_id", "txn-legacy");
        payload.put("product_id", "ultrasend_pro_lifetime");
        payload.put("app_user_id", "456");
        payload.put("event", "INITIAL_PURCHASE");

        RevenueCatDomesticWebhookParser.Parsed parsed =
                RevenueCatDomesticWebhookParser.parse(payload);

        assertEquals("txn-legacy", parsed.transactionId());
        assertEquals("ultrasend_pro_lifetime", parsed.productId());
        assertEquals("456", parsed.appUserId());
        assertEquals("INITIAL_PURCHASE", parsed.eventType());
    }

    @Test
    void parse_appUserIdFallbackToTopLevel() {
        Map<String, Object> event = new HashMap<>();
        event.put("type", "NON_RENEWING_PURCHASE");
        event.put("product_id", "ultrasend_addon_5_devices");
        event.put("transaction_id", "txn-addon");
        Map<String, Object> payload = new HashMap<>();
        payload.put("event", event);
        payload.put("app_user_id", "789");

        RevenueCatDomesticWebhookParser.Parsed parsed =
                RevenueCatDomesticWebhookParser.parse(payload);

        assertEquals("789", parsed.appUserId());
        assertEquals("ultrasend_addon_5_devices", parsed.productId());
    }
}
