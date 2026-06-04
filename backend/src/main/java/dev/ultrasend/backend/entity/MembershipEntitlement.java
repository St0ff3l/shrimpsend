package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "membership_entitlements")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MembershipEntitlement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "tier_code", nullable = false, length = 16)
    private String tierCode;

    @Column(name = "device_limit", nullable = false)
    private Integer deviceLimit;

    @Column(name = "addon_packs", nullable = false)
    @Builder.Default
    private Integer addonPacks = 0;

    @Column(name = "is_lifetime", nullable = false)
    private Boolean isLifetime;

    @Column(name = "effective_at", nullable = false)
    private Instant effectiveAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** Overseas subscription period end; null = FREE or lifetime (domestic). */
    @Column(name = "subscription_expires_at")
    private Instant subscriptionExpiresAt;

    /** MONTHLY / YEARLY — overseas Stripe or RC subscription. */
    @Column(name = "billing_period", length = 16)
    private String billingPeriod;

    /**
     * Stripe only: {@code true} when user turned off auto-renew (cancel at period end).
     * {@code null} for RevenueCat / unknown.
     */
    @Column(name = "subscription_cancel_at_period_end")
    private Boolean subscriptionCancelAtPeriodEnd;

    @Column(name = "stripe_customer_id", length = 64)
    private String stripeCustomerId;

    @Column(name = "stripe_subscription_id", length = 64)
    private String stripeSubscriptionId;

    /**
     * Active payment channel for this entitlement: FREE / APPLE_RC / GOOGLE_RC / STRIPE / ALIPAY_LIFETIME.
     * Used to enforce cross-platform channel affinity (manage / upgrade in the channel where you paid).
     */
    @Column(name = "payment_channel", length = 16)
    private String paymentChannel;
}
