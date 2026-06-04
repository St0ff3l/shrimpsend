package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "qr_login_sessions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QrLoginSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "session_id", nullable = false, unique = true, length = 36)
    private String sessionId;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_SCANNED = "SCANNED";
    public static final String STATUS_CONFIRMED = "CONFIRMED";
    public static final String STATUS_CONSUMED = "CONSUMED";
    public static final String STATUS_CANCELLED = "CANCELLED";
    public static final String STATUS_EXPIRED = "EXPIRED";
}
