package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(
        name = "device_presence_sessions",
        uniqueConstraints = {
                @UniqueConstraint(columnNames = {"user_id", "device_id", "session_id"})
        },
        indexes = {
                @Index(name = "idx_device_presence_active", columnList = "user_id,device_id,closed_at,last_seen")
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DevicePresenceSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "device_id", nullable = false, length = 128)
    private String deviceId;

    @Column(name = "session_id", nullable = false, length = 128)
    private String sessionId;

    @Column(length = 16)
    private String platform;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "last_seen", nullable = false)
    private Instant lastSeen;

    @Column(name = "closed_at")
    private Instant closedAt;
}
