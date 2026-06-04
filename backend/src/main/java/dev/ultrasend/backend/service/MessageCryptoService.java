package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.MessageEncryptionProperties;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class MessageCryptoService {

    private static final String PREFIX = "enc:v1:";
    private static final int NONCE_BYTES = 12;
    private static final int GCM_TAG_BITS = 128;
    private static final String CIPHER = "AES/GCM/NoPadding";

    private final MessageEncryptionProperties properties;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();

    private SecretKeySpec keySpec;

    @PostConstruct
    void init() {
        byte[] key = configuredKey();
        validateAesKey(key);
        keySpec = new SecretKeySpec(key, "AES");
    }

    public boolean isEncrypted(String value) {
        return value != null && value.startsWith(PREFIX);
    }

    public String encrypt(String plaintext) {
        if (plaintext == null) {
            throw new IllegalArgumentException("Message plaintext cannot be null");
        }
        try {
            byte[] nonce = new byte[NONCE_BYTES];
            secureRandom.nextBytes(nonce);
            Cipher cipher = Cipher.getInstance(CIPHER);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, new GCMParameterSpec(GCM_TAG_BITS, nonce));
            byte[] ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
            return PREFIX + encoder.encodeToString(nonce) + ":" + encoder.encodeToString(ciphertext);
        } catch (Exception e) {
            throw new IllegalStateException("Message encryption failed", e);
        }
    }

    public String decryptIfNeeded(String storedValue) {
        if (!isEncrypted(storedValue)) {
            return storedValue;
        }
        String[] parts = storedValue.substring(PREFIX.length()).split(":", 2);
        if (parts.length != 2) {
            throw new IllegalArgumentException("Invalid encrypted message format");
        }
        try {
            Base64.Decoder decoder = Base64.getUrlDecoder();
            byte[] nonce = decoder.decode(parts[0]);
            byte[] ciphertext = decoder.decode(parts[1]);
            Cipher cipher = Cipher.getInstance(CIPHER);
            cipher.init(Cipher.DECRYPT_MODE, keySpec, new GCMParameterSpec(GCM_TAG_BITS, nonce));
            return new String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8);
        } catch (AEADBadTagException e) {
            throw new IllegalArgumentException("Encrypted message authentication failed", e);
        } catch (Exception e) {
            throw new IllegalArgumentException("Encrypted message decrypt failed", e);
        }
    }

    public Map<String, Object> encryptTextPayloadInEnvelope(Map<String, Object> envelope) {
        Map<String, Object> copy = new LinkedHashMap<>(envelope);
        if (!isTextEnvelope(copy)) {
            return copy;
        }
        Object payloadObj = copy.get("payload");
        if (!(payloadObj instanceof Map<?, ?> payload)) {
            return copy;
        }
        Map<String, Object> payloadCopy = new LinkedHashMap<>();
        payload.forEach((key, value) -> payloadCopy.put(String.valueOf(key), value));
        Object text = payloadCopy.get("text");
        if (text instanceof String value && !isEncrypted(value)) {
            payloadCopy.put("text", encrypt(value));
        }
        copy.put("payload", payloadCopy);
        return copy;
    }

    public void decryptTextPayloadInEnvelope(Map<String, Object> envelope) {
        if (!isTextEnvelope(envelope)) {
            return;
        }
        Object payloadObj = envelope.get("payload");
        if (!(payloadObj instanceof Map<?, ?> payload)) {
            return;
        }
        Object text = payload.get("text");
        if (!(text instanceof String value) || !isEncrypted(value)) {
            return;
        }
        @SuppressWarnings("unchecked")
        Map<Object, Object> mutablePayload = (Map<Object, Object>) payload;
        mutablePayload.put("text", decryptIfNeeded(value));
    }

    private static boolean isTextEnvelope(Map<String, Object> envelope) {
        Object type = envelope.get("type");
        return type != null && "text".equals(type.toString());
    }

    private byte[] configuredKey() {
        String raw = properties.getKeyBase64();
        if (raw != null && !raw.isBlank()) {
            return Base64.getDecoder().decode(raw.trim());
        }
        if (isProdLikeProfile() || !properties.isAllowDevFallbackKey()) {
            throw new IllegalStateException("app.messages.encryption.key-base64 is required");
        }
        throw new IllegalStateException(
                "app.messages.encryption.key-base64 is required for local dev; "
                        + "run scripts/setup-local-config.sh to generate backend/.env");
    }

    private boolean isProdLikeProfile() {
        return Arrays.stream(environment.getActiveProfiles())
                .anyMatch(profile -> profile.equals("prod") || profile.startsWith("prod-"));
    }

    private static void validateAesKey(byte[] key) {
        int length = key != null ? key.length : 0;
        if (length != 16 && length != 24 && length != 32) {
            throw new IllegalArgumentException("Message encryption key must be 16, 24, or 32 bytes");
        }
    }
}
