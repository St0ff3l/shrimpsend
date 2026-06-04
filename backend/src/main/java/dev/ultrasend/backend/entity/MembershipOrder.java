package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "membership_orders")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MembershipOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_no", nullable = false, unique = true, length = 64)
    private String orderNo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "from_tier", nullable = false, length = 16)
    private String fromTier;

    @Column(name = "to_tier", nullable = false, length = 16)
    private String toTier;

    @Column(name = "payable_amount_cent", nullable = false)
    private Integer payableAmountCent;

    @Column(name = "currency", nullable = false, length = 8)
    private String currency;

    @Column(name = "channel", nullable = false, length = 16)
    private String channel;

    @Column(name = "order_type", nullable = false, length = 16)
    @Builder.Default
    private String orderType = "TIER";

    @Column(name = "status", nullable = false, length = 24)
    private String status;

    @Column(name = "provider_order_id", length = 128)
    private String providerOrderId;

    @Column(name = "provider_trade_id", length = 128)
    private String providerTradeId;

    @Column(name = "provider_payload", columnDefinition = "TEXT")
    private String providerPayload;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "paid_at")
    private Instant paidAt;

    @Column(name = "granted_at")
    private Instant grantedAt;
}
