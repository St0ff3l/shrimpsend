package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import dev.ultrasend.backend.config.MessageEncryptionProperties;
import dev.ultrasend.backend.entity.Message;
import dev.ultrasend.backend.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class MessageEncryptionMigrationRunner {

    private static final int BATCH_SIZE = 200;
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final MessageEncryptionProperties properties;
    private final MessageRepository messageRepository;
    private final MessageCryptoService messageCryptoService;
    private final ObjectMapper objectMapper;

    @EventListener(ApplicationReadyEvent.class)
    public void migrateOnStartup() {
        if (!properties.isMigrateOnStartup()) {
            return;
        }
        migratePlaintextMessages();
    }

    @Transactional
    public void migratePlaintextMessages() {
        long cursor = 0L;
        long scanned = 0L;
        long encrypted = 0L;
        while (true) {
            List<Message> batch = messageRepository.findByIdGreaterThanOrderByIdAsc(
                    cursor,
                    PageRequest.of(0, BATCH_SIZE));
            if (batch.isEmpty()) {
                break;
            }
            for (Message message : batch) {
                cursor = message.getId();
                scanned++;
                String data = message.getData();
                try {
                    String json = messageCryptoService.decryptIfNeeded(data);
                    Map<String, Object> envelope = objectMapper.readValue(json, MAP_TYPE);
                    Map<String, Object> encryptedEnvelope =
                            messageCryptoService.encryptTextPayloadInEnvelope(envelope);
                    String migrated = objectMapper.writeValueAsString(encryptedEnvelope);
                    if (!migrated.equals(data)) {
                        message.setData(migrated);
                        encrypted++;
                    }
                } catch (Exception e) {
                    log.warn("message encryption migration skipped id={} reason={}",
                            message.getId(), e.getClass().getSimpleName());
                }
            }
            messageRepository.saveAll(batch);
        }
        log.info("message encryption migration finished scanned={} encrypted={}", scanned, encrypted);
    }
}
