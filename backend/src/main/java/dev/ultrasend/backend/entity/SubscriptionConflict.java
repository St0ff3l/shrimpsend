package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

/**
 * Records when two payment channels are active for the same user simultaneously.
 *
 * <p>Written by webhook handlers when an incoming RC / Stripe event would
 * overwrite a still-active subscription from the other channel. Operations
 * staff can use this to reach out and help users cancel one side.
 */
@Entity
@Table(name = "subscription_conflicts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SubscriptionConflict {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "detected_at", nullable = false)
    private Instant detectedAt;

    @Column(name = "active_channels", nullable = false, length = 128)
    private String activeChannels;

    @Column(name = "incoming_channel", nullable = false, length = 16)
    private String incomingChannel;

    @Column(name = "existing_channel", nullable = false, length = 16)
    private String existingChannel;

    @Column(name = "incoming_tier", length = 16)
    private String incomingTier;

    @Column(name = "existing_tier", length = 16)
    private String existingTier;

    @Column(name = "incoming_expires_at")
    private Instant incomingExpiresAt;

    @Column(name = "existing_expires_at")
    private Instant existingExpiresAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    @Column(name = "note", length = 512)
    private String note;

    @Column(name = "payload_excerpt", length = 1024)
    private String payloadExcerpt;
}
