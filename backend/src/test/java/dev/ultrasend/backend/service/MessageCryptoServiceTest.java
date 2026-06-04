package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.MessageEncryptionProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.Environment;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

class MessageCryptoServiceTest {

    private MessageCryptoService cryptoService;

    @BeforeEach
    void setUp() {
        MessageEncryptionProperties properties = new MessageEncryptionProperties();
        properties.setKeyBase64(Base64.getEncoder().encodeToString(
                "12345678901234567890123456789012".getBytes(StandardCharsets.UTF_8)));
        Environment environment = mock(Environment.class);
        cryptoService = new MessageCryptoService(properties, environment);
        cryptoService.init();
    }

    @Test
    void encryptProducesVersionedCiphertextWithRandomNonce() {
        String first = cryptoService.encrypt("{\"payload\":{\"text\":\"hello\"}}");
        String second = cryptoService.encrypt("{\"payload\":{\"text\":\"hello\"}}");

        assertTrue(first.startsWith("enc:v1:"));
        assertTrue(second.startsWith("enc:v1:"));
        assertNotEquals(first, second);
        assertFalse(first.contains("hello"));
    }

    @Test
    void decryptIfNeededSupportsCiphertextAndLegacyPlaintext() {
        String plaintext = "{\"type\":\"text\",\"payload\":{\"text\":\"hello\"}}";
        String ciphertext = cryptoService.encrypt(plaintext);

        assertEquals(plaintext, cryptoService.decryptIfNeeded(ciphertext));
        assertEquals(plaintext, cryptoService.decryptIfNeeded(plaintext));
    }

    @Test
    void tamperedCiphertextFailsAuthentication() {
        String ciphertext = cryptoService.encrypt("{\"payload\":{\"text\":\"hello\"}}");
        String tampered = ciphertext.substring(0, ciphertext.length() - 1)
                + (ciphertext.endsWith("A") ? "B" : "A");

        assertThrows(IllegalArgumentException.class, () -> cryptoService.decryptIfNeeded(tampered));
    }
}
