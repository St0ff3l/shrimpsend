package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class UserDekMigrationRunner {

    private static final int BATCH_SIZE = 200;

    private final UserDataEncryptionProperties properties;
    private final UserRepository userRepository;
    private final UserDataEncryptionService userDataEncryption;

    @Order(1)
    @EventListener(ApplicationReadyEvent.class)
    public void migrateOnStartup() {
        if (!shouldRun()) {
            return;
        }
        backfillMissingUserDeks();
    }

    boolean shouldRun() {
        return properties.isMigrateUserDekOnStartup()
                || properties.isMigrateS3OnStartup()
                || properties.isMigrateMessagesOnStartup();
    }

    @Transactional
    public void backfillMissingUserDeks() {
        long cursor = 0L;
        long scanned = 0L;
        long initialized = 0L;
        long skipped = 0L;
        while (true) {
            List<User> batch = userRepository.findWithoutDekAfterId(cursor, PageRequest.of(0, BATCH_SIZE));
            if (batch.isEmpty()) {
                break;
            }
            for (User user : batch) {
                cursor = user.getId();
                scanned++;
                try {
                    userDataEncryption.ensureUserKey(user.getId());
                    initialized++;
                } catch (Exception e) {
                    skipped++;
                    log.warn("user DEK migration skipped userId={} reason={}", user.getId(), e.getMessage());
                }
            }
        }
        log.info("user DEK migration finished scanned={} initialized={} skipped={}",
                scanned, initialized, skipped);
    }
}
