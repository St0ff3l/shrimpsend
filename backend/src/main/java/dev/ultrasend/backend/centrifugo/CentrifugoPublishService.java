package dev.ultrasend.backend.centrifugo;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * Publishes messages to Centrifugo user channel via HTTP API.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CentrifugoPublishService {

    private static final String CHANNEL_PREFIX = "user#";

    private final WebClient centrifugoWebClient;
    private final ObjectMapper objectMapper;

    public void publishToUser(String userId, Object data) {
        String channel = CHANNEL_PREFIX + userId;
        ObjectNode body = objectMapper.createObjectNode()
                .put("method", "publish")
                .set("params", objectMapper.createObjectNode()
                        .put("channel", channel)
                        .set("data", objectMapper.valueToTree(data)));
        try {
            centrifugoWebClient.post()
                    .uri("/api")
                    .bodyValue(body)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            log.info("Centrifugo publish ok channel={}", channel);
        } catch (Exception e) {
            log.error("Centrifugo publish failed for channel {}: {}", channel, e.getMessage());
            throw new RuntimeException("Failed to publish message", e);
        }
    }
}
