package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(
        name = "membership_order_events",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_membership_event_unique", columnNames = {"provider", "event_unique_key"})
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MembershipOrderEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "provider", nullable = false, length = 24)
    private String provider;

    @Column(name = "event_type", nullable = false, length = 64)
    private String eventType;

    @Column(name = "event_unique_key", nullable = false, length = 128)
    private String eventUniqueKey;

    @Column(name = "order_no", length = 64)
    private String orderNo;

    @Column(name = "payload", columnDefinition = "TEXT")
    private String payload;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
}
