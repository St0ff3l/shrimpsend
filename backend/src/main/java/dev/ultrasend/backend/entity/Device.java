package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(
        name = "devices",
        uniqueConstraints = {
                @UniqueConstraint(columnNames = {"device_id"}),
                @UniqueConstraint(columnNames = {"user_id", "display_code"})
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "device_id", nullable = false)
    private String deviceId; // immutable client-generated id

    @Column(nullable = false)
    private String name;

    @Column(length = 16)
    private String platform;

    @Column(name = "lan_http_url", length = 512)
    private String lanHttpUrl;

    @Column(name = "last_seen")
    private Instant lastSeen;

    @Column(name = "presence_status", nullable = false, length = 16)
    @Builder.Default
    private String presenceStatus = "offline";

    @Column(name = "presence_updated_at")
    private Instant presenceUpdatedAt;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "session_version", nullable = false)
    @Builder.Default
    private int sessionVersion = 0;

    /** 1–999 per user for UI chips; null when kicked (inactive). */
    @Column(name = "display_code")
    private Integer displayCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
