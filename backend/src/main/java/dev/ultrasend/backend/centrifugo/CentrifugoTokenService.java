package dev.ultrasend.backend.centrifugo;

import dev.ultrasend.backend.dto.CentrifugoTokenResponse;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * Issues JWTs for Centrifugo connection and subscription (user channel).
 * Uses same HMAC secret as Centrifugo config.json client.token.hmac_secret_key.
 */
@Service
public class CentrifugoTokenService {

    private static final String CHANNEL_PREFIX = "user#";

    private final SecretKey hmacKey;
    private final long connectionExpirationSec;
    private final long subscriptionExpirationSec;

    public CentrifugoTokenService(
            @Value("${centrifugo.token-hmac-secret}") String tokenHmacSecret,
            @Value("${centrifugo.connection-token-expiration-sec:3600}") long connectionExpirationSec,
            @Value("${centrifugo.subscription-token-expiration-sec:3600}") long subscriptionExpirationSec) {
        this.hmacKey = Keys.hmacShaKeyFor(tokenHmacSecret.getBytes(StandardCharsets.UTF_8));
        this.connectionExpirationSec = connectionExpirationSec;
        this.subscriptionExpirationSec = subscriptionExpirationSec;
    }

    public CentrifugoTokenResponse createTokens(String userId) {
        String channel = CHANNEL_PREFIX + userId;
        String connectionToken = createConnectionToken(userId);
        String subscriptionToken = createSubscriptionToken(userId, channel);
        return CentrifugoTokenResponse.builder()
                .connectionToken(connectionToken)
                .subscriptionToken(subscriptionToken)
                .channel(channel)
                .build();
    }

    /**
     * Connection JWT: 使用 expire_at=0 让 Centrifugo 不因过期主动断开连接（见 Centrifugo 文档 expire_at）。
     * 仍保留 exp 作为 JWT 有效性，避免 token 永久有效。
     */
    private String createConnectionToken(String userId) {
        return Jwts.builder()
                .subject(userId)
                .expiration(new Date(System.currentTimeMillis() + connectionExpirationSec * 1000L))
                .claim("expire_at", 0)
                .signWith(hmacKey)
                .compact();
    }

    private String createSubscriptionToken(String userId, String channel) {
        return Jwts.builder()
                .subject(userId)
                .claim("channel", channel)
                .expiration(new Date(System.currentTimeMillis() + subscriptionExpirationSec * 1000L))
                .signWith(hmacKey)
                .compact();
    }
}
