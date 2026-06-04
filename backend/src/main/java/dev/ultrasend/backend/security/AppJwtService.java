package dev.ultrasend.backend.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Service
public class AppJwtService {

    private final SecretKey accessKey;
    private final long accessExpirationMs;
    private final SecretKey refreshKey;
    private final long refreshExpirationMs;

    public AppJwtService(
            @Value("${app.jwt.access-secret}") String accessSecret,
            @Value("${app.jwt.access-expiration-ms}") long accessExpirationMs,
            @Value("${app.jwt.refresh-secret}") String refreshSecret,
            @Value("${app.jwt.refresh-expiration-ms}") long refreshExpirationMs) {
        this.accessKey = Keys.hmacShaKeyFor(accessSecret.getBytes(StandardCharsets.UTF_8));
        this.accessExpirationMs = accessExpirationMs;
        this.refreshKey = Keys.hmacShaKeyFor(refreshSecret.getBytes(StandardCharsets.UTF_8));
        this.refreshExpirationMs = refreshExpirationMs;
    }

    public String generateAccessToken(String userId, String username) {
        return buildAccessToken(userId, username, null, null);
    }

    public String generateAccessToken(String userId, String username, String deviceId, int deviceSessionVersion) {
        return buildAccessToken(userId, username, deviceId, deviceSessionVersion);
    }

    private String buildAccessToken(String userId, String username, String deviceId, Integer deviceSessionVersion) {
        JwtBuilder b = Jwts.builder()
                .subject(userId)
                .claim("username", username)
                .claim("type", "access")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + accessExpirationMs))
                .signWith(accessKey);
        if (deviceId != null && deviceSessionVersion != null) {
            b.claim("did", deviceId).claim("dsv", deviceSessionVersion);
        }
        return b.compact();
    }

    public String generateRefreshToken(String userId) {
        return buildRefreshToken(userId, null, null);
    }

    public String generateRefreshToken(String userId, String deviceId, int deviceSessionVersion) {
        return buildRefreshToken(userId, deviceId, deviceSessionVersion);
    }

    private String buildRefreshToken(String userId, String deviceId, Integer deviceSessionVersion) {
        JwtBuilder b = Jwts.builder()
                .subject(userId)
                .claim("type", "refresh")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + refreshExpirationMs))
                .signWith(refreshKey);
        if (deviceId != null && deviceSessionVersion != null) {
            b.claim("did", deviceId).claim("dsv", deviceSessionVersion);
        }
        return b.compact();
    }

    public String parseAccessTokenSubject(String token) {
        return parseAccessClaims(accessKey, token).getSubject();
    }

    public ParsedAuthToken parseAccessToken(String token) {
        Claims c = parseAccessClaims(accessKey, token);
        if (!"access".equals(c.get("type"))) {
            throw new JwtException("Invalid token type");
        }
        return new ParsedAuthToken(
                c.getSubject(),
                c.get("did", String.class),
                c.get("dsv") != null ? c.get("dsv", Integer.class) : null);
    }

    public String parseRefreshTokenSubject(String token) {
        return parseRefreshClaims(refreshKey, token).getSubject();
    }

    public ParsedAuthToken parseRefreshToken(String token) {
        Claims c = parseRefreshClaims(refreshKey, token);
        if (!"refresh".equals(c.get("type"))) {
            throw new JwtException("Invalid token type");
        }
        return new ParsedAuthToken(
                c.getSubject(),
                c.get("did", String.class),
                c.get("dsv") != null ? c.get("dsv", Integer.class) : null);
    }

    private static Claims parseAccessClaims(SecretKey key, String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private static Claims parseRefreshClaims(SecretKey key, String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public long getAccessExpirationSeconds() {
        return accessExpirationMs / 1000;
    }

    public record ParsedAuthToken(String userId, String deviceId, Integer deviceSessionVersion) {}
}
