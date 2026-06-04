package dev.ultrasend.backend.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Getter
@Setter
@ConfigurationProperties(prefix = "app.messages.encryption")
public class MessageEncryptionProperties {

    /**
     * Base64-encoded 128/192/256-bit AES key. Production must provide this via
     * environment/configuration, not source control.
     */
    private String keyBase64 = "";

    /**
     * Allows local development and tests to boot without a configured key. This
     * is rejected when a prod-like Spring profile is active.
     */
    private boolean allowDevFallbackKey = true;

    /**
     * Optional one-shot migration for existing plaintext message rows.
     */
    private boolean migrateOnStartup = false;
}
