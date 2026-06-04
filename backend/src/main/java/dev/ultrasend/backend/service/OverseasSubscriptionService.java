package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.OverseasBillingProperties;
import dev.ultrasend.backend.entity.MembershipEntitlement;
import dev.ultrasend.backend.entity.MembershipOrder;
import dev.ultrasend.backend.entity.MembershipOrderEvent;
import dev.ultrasend.backend.entity.SubscriptionConflict;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.membership.MembershipChannel;
import dev.ultrasend.backend.membership.MembershipOrderStatus;
import dev.ultrasend.backend.membership.MembershipOrderType;
import dev.ultrasend.backend.membership.OverseasMembershipTier;
import dev.ultrasend.backend.repository.MembershipEntitlementRepository;
import dev.ultrasend.backend.repository.MembershipOrderEventRepository;
import dev.ultrasend.backend.repository.MembershipOrderRepository;
import dev.ultrasend.backend.repository.SubscriptionConflictRepository;
import dev.ultrasend.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class OverseasSubscriptionService {

    private final ClusterDeploymentService clusterDeploymentService;
    private final HostedQuotaService hostedQuotaService;
    private final OverseasBillingProperties overseasBillingProperties;
    private final MembershipEntitlementRepository membershipEntitlementRepository;
    private final MembershipOrderEventRepository membershipOrderEventRepository;
    private final MembershipOrderRepository membershipOrderRepository;
    private final SubscriptionConflictRepository subscriptionConflictRepository;
    private final UserRepository userRepository;

    public record SubscriptionGrant(OverseasMembershipTier tier, String billingPeriod) {}

    public Optional<SubscriptionGrant> resolveRcProductId(String productId) {
        if (productId == null || productId.isBlank()) {
            return Optional.empty();
        }
        String normalized = normalizeRcProductId(productId);
        if (!normalized.equals(productId.trim())) {
            log.info("revenuecat productId normalized raw={} normalized={}", productId, normalized);
        }
        OverseasBillingProperties p = overseasBillingProperties;
        if (normalized.equals(p.getRcPlusMonthly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PLUS, "MONTHLY"));
        if (normalized.equals(p.getRcPlusYearly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PLUS, "YEARLY"));
        if (normalized.equals(p.getRcProMonthly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PRO, "MONTHLY"));
        if (normalized.equals(p.getRcProYearly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PRO, "YEARLY"));
        if (normalized.equals(p.getRcUltraMonthly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.ULTRA, "MONTHLY"));
        if (normalized.equals(p.getRcUltraYearly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.ULTRA, "YEARLY"));
        return Optional.empty();
    }

    /**
     * Google Play subscriptions use {@code productId:basePlanId} (e.g. {@code shrimpsend_plus_monthly:default});
     * RevenueCat webhooks pass that full string while our catalog stores the subscription id only.
     */
    static String normalizeRcProductId(String productId) {
        String trimmed = productId.trim();
        int colon = trimmed.indexOf(':');
        if (colon > 0) {
            return trimmed.substring(0, colon);
        }
        return trimmed;
    }

    public Optional<SubscriptionGrant> resolveStripePriceId(String priceId) {
        if (priceId == null || priceId.isBlank()) {
            return Optional.empty();
        }
        OverseasBillingProperties p = overseasBillingProperties;
        if (priceId.equals(p.getStripePricePlusMonthly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PLUS, "MONTHLY"));
        if (priceId.equals(p.getStripePricePlusYearly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PLUS, "YEARLY"));
        if (priceId.equals(p.getStripePriceProMonthly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PRO, "MONTHLY"));
        if (priceId.equals(p.getStripePriceProYearly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.PRO, "YEARLY"));
        if (priceId.equals(p.getStripePriceUltraMonthly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.ULTRA, "MONTHLY"));
        if (priceId.equals(p.getStripePriceUltraYearly())) return Optional.of(new SubscriptionGrant(OverseasMembershipTier.ULTRA, "YEARLY"));
        return Optional.empty();
    }

    /**
     * Single-line summary of the six configured Stripe Price IDs (empty slots shown as {@code (empty)}).
     */
    public String stripePriceCatalogForLog() {
        OverseasBillingProperties p = overseasBillingProperties;
        return String.format(
                "plusM=%s plusY=%s proM=%s proY=%s ultraM=%s ultraY=%s",
                nz(p.getStripePricePlusMonthly()),
                nz(p.getStripePricePlusYearly()),
                nz(p.getStripePriceProMonthly()),
                nz(p.getStripePriceProYearly()),
                nz(p.getStripePriceUltraMonthly()),
                nz(p.getStripePriceUltraYearly()));
    }

    private static String nz(String s) {
        return (s == null || s.isBlank()) ? "(empty)" : s.trim();
    }

    public void logStripePriceRequest(String action, long userId, String incomingPriceId) {
        log.info("stripe_price_debug action={} userId={} incoming={} catalog={}",
                action, userId, incomingPriceId != null ? incomingPriceId : "(null)", stripePriceCatalogForLog());
    }

    public boolean isEnabled() {
        return clusterDeploymentService.isOverseasDeployment();
    }

    public Optional<String> findStripeSubscriptionId(long userId) {
        return membershipEntitlementRepository.findByUserId(userId)
                .map(MembershipEntitlement::getStripeSubscriptionId)
                .filter(id -> id != null && !id.isBlank());
    }

    public Optional<String> findStripeCustomerId(long userId) {
        return membershipEntitlementRepository.findByUserId(userId)
                .map(MembershipEntitlement::getStripeCustomerId)
                .filter(id -> id != null && !id.isBlank());
    }

    /**
     * Ensures target price is a higher tier than current entitlement and user has an active Stripe subscription row.
     */
    public void validateStripeSubscriptionUpgrade(long userId, String newPriceId) {
        Optional<SubscriptionGrant> grantOpt = resolveStripePriceId(newPriceId);
        if (grantOpt.isEmpty()) {
            log.warn("stripe_price_unknown action=subscription-upgrade userId={} incoming={} catalog={}",
                    userId, newPriceId, stripePriceCatalogForLog());
            throw new IllegalArgumentException("未知 Stripe Price");
        }
        SubscriptionGrant target = grantOpt.get();
        OverseasMembershipTier current = hostedQuotaService.effectiveTier(userId);
        if (target.tier().getRank() <= current.getRank()) {
            throw new IllegalArgumentException("仅支持升级到更高档位");
        }
        findStripeSubscriptionId(userId).orElseThrow(
                () -> new IllegalArgumentException("请先在网页完成 Stripe 订阅后再升级"));
    }

    /**
     * Handles RevenueCat webhook body (supports nested {@code event} object).
     */
    @Transactional
    public boolean processRevenueCatPayload(Map<String, Object> payload) {
        if (!isEnabled()) {
            return false;
        }
        @SuppressWarnings("unchecked")
        Map<String, Object> event = payload.containsKey("event") && payload.get("event") instanceof Map
                ? (Map<String, Object>) payload.get("event")
                : payload;

        String eventType = asString(event.get("type"));
        if (eventType == null) {
            eventType = asString(payload.get("event"));
        }

        String eventId = asString(event.get("id"));
        String productId = asString(event.get("product_id"));
        String appUserId = asString(event.get("app_user_id"));
        if (appUserId == null || appUserId.isBlank()) {
            appUserId = asString(payload.get("app_user_id"));
        }
        String store = asString(event.get("store"));

        Long expirationMs = parseLongMs(event.get("expiration_at_ms"));

        log.info(
                "revenuecat overseas processing eventType={} eventId={} appUserId={} productId={} store={} expirationMs={}",
                eventType,
                eventId,
                appUserId,
                productId,
                store,
                expirationMs);

        if (appUserId == null || appUserId.isBlank()) {
            throw new IllegalArgumentException("app_user_id 为空");
        }
        long userId = Long.parseLong(appUserId.trim());

        String idempotencyKey = eventId != null && !eventId.isBlank()
                ? "RC_EVT:" + eventId
                : "RC_LEGACY:" + asString(event.get("transaction_id")) + ":" + productId;

        if (membershipOrderEventRepository.existsByProviderAndEventUniqueKey("REVENUECAT_OS", idempotencyKey)) {
            log.info("revenuecat overseas duplicate key={}", idempotencyKey);
            return false;
        }

        membershipOrderEventRepository.save(MembershipOrderEvent.builder()
                .provider("REVENUECAT_OS")
                .eventType(eventType != null ? eventType : "UNKNOWN")
                .eventUniqueKey(idempotencyKey)
                .payload(payload.toString())
                .createdAt(Instant.now())
                .build());

        // EXPIRATION / REFUND / REVOKE end access immediately.
        // CANCELLATION keeps entitlement until period end (handled by RC expiration).
        if ("EXPIRATION".equalsIgnoreCase(eventType)
                || "REFUND".equalsIgnoreCase(eventType)
                || "REVOKE".equalsIgnoreCase(eventType)) {
            log.info("revenuecat overseas action=downgrade userId={} eventType={}", userId, eventType);
            downgradeToFree(userId);
            return true;
        }

        if ("BILLING_ISSUE".equalsIgnoreCase(eventType)) {
            log.info("revenuecat overseas action=billing_issue userId={}", userId);
            return true;
        }

        Optional<SubscriptionGrant> grantOpt = resolveRcProductId(productId);
        if (grantOpt.isEmpty()) {
            log.info("revenuecat overseas action=skip_unknown_product eventType={} productId={}", eventType, productId);
            return true;
        }

        SubscriptionGrant grant = grantOpt.get();
        Instant expiresAt = expirationMs != null
                ? Instant.ofEpochMilli(expirationMs)
                : Instant.now().plusSeconds("YEARLY".equals(grant.billingPeriod()) ? 366L * 86400 : 32L * 86400);

        MembershipChannel rcChannel = resolveRcChannelFromStore(store);
        log.info(
                "revenuecat overseas action=grant userId={} tier={} billingPeriod={} expiresAt={} channel={}",
                userId,
                grant.tier().getCode(),
                grant.billingPeriod(),
                expiresAt,
                rcChannel.name());
        upsertSubscription(userId, grant.tier(), grant.billingPeriod(), expiresAt,
                rcChannel.name(), productId, payload.toString(), null, null);
        return true;
    }

    /**
     * Maps RevenueCat's {@code store} field to our channel. RC values are typically
     * {@code APP_STORE} / {@code PLAY_STORE} / {@code AMAZON} / {@code MAC_APP_STORE}.
     * Defaults to {@link MembershipChannel#APPLE_RC} when unknown (iOS dominates currently).
     */
    static MembershipChannel resolveRcChannelFromStore(String store) {
        if (store == null) return MembershipChannel.APPLE_RC;
        String s = store.trim().toUpperCase(Locale.ROOT);
        if (s.startsWith("PLAY")) return MembershipChannel.GOOGLE_RC;
        return MembershipChannel.APPLE_RC;
    }

    @Transactional
    public void applyStripeSubscription(Long userId, String subscriptionId, String stripeCustomerId,
                                        String priceId, Instant currentPeriodEnd, String rawPayload,
                                        Boolean cancelAtPeriodEnd) {
        if (!isEnabled()) {
            return;
        }
        Optional<SubscriptionGrant> grantOpt = resolveStripePriceId(priceId);
        if (grantOpt.isEmpty()) {
            log.warn("stripe_price_unknown action=apply-stripe-subscription userId={} incoming={} catalog={}",
                    userId, priceId, stripePriceCatalogForLog());
            throw new IllegalArgumentException("Unknown Stripe price: " + priceId);
        }
        SubscriptionGrant grant = grantOpt.get();
        upsertSubscription(userId, grant.tier(), grant.billingPeriod(), currentPeriodEnd,
                "STRIPE", subscriptionId, rawPayload, stripeCustomerId, cancelAtPeriodEnd);
    }

    @Transactional
    public void stripeSubscriptionEnded(Long userId) {
        if (!isEnabled()) {
            return;
        }
        downgradeToFree(userId);
    }

    private void upsertSubscription(Long userId, OverseasMembershipTier tier, String billingPeriod,
                                   Instant expiresAt, String channel, String externalRef, String payloadNote,
                                   String stripeCustomerId, Boolean stripeCancelAtPeriodEnd) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        MembershipEntitlement ent = membershipEntitlementRepository.findByUserId(userId)
                .orElse(MembershipEntitlement.builder()
                        .user(user)
                        .tierCode(OverseasMembershipTier.FREE.getCode())
                        .deviceLimit(3)
                        .addonPacks(0)
                        .isLifetime(false)
                        .effectiveAt(Instant.now())
                        .updatedAt(Instant.now())
                        .build());

        // Cross-channel conflict detection: if the existing row belongs to a different
        // still-active channel, log to subscription_conflicts and keep the longer expiry
        // so neither side's external ref is silently lost.
        String existingChannel = ent.getPaymentChannel();
        Instant existingExpiry = ent.getSubscriptionExpiresAt();
        boolean existingActive = existingChannel != null
                && !"FREE".equals(existingChannel)
                && existingExpiry != null
                && existingExpiry.isAfter(Instant.now());
        boolean isConflict = existingActive
                && !existingChannel.equals(channel)
                && !"ALIPAY_LIFETIME".equals(existingChannel);
        if (isConflict) {
            recordConflict(userId, channel, existingChannel, tier.getCode(),
                    ent.getTierCode(), expiresAt, existingExpiry, payloadNote);
            // Defer to whichever side covers a longer window; do NOT clear the other
            // channel's identifiers so ops can reconcile manually.
            if (existingExpiry.isAfter(expiresAt == null ? Instant.EPOCH : expiresAt)) {
                log.warn("subscription conflict userId={} keeping existingChannel={} until={} incoming={} ignored",
                        userId, existingChannel, existingExpiry, channel);
                return;
            }
            // Incoming side wins on expiry; still keep the *other* channel's ref by NOT
            // clearing it (handled below via per-channel writes only).
            log.warn("subscription conflict userId={} replacing existingChannel={} with={} expiry={}",
                    userId, existingChannel, channel, expiresAt);
        }

        ent.setTierCode(tier.getCode());
        ent.setDeviceLimit(tier.getDeviceLimit());
        ent.setAddonPacks(0);
        ent.setIsLifetime(false);
        ent.setBillingPeriod(billingPeriod);
        ent.setSubscriptionExpiresAt(expiresAt);
        if ("STRIPE".equals(channel)) {
            ent.setStripeSubscriptionId(externalRef);
            ent.setStripeCustomerId(stripeCustomerId);
            ent.setSubscriptionCancelAtPeriodEnd(
                    stripeCancelAtPeriodEnd != null ? stripeCancelAtPeriodEnd : Boolean.FALSE);
        } else if (!isConflict) {
            // Only clear Stripe fields when there is no conflict; conflict path preserves both.
            ent.setStripeSubscriptionId(null);
            ent.setStripeCustomerId(null);
            ent.setSubscriptionCancelAtPeriodEnd(null);
        }
        ent.setPaymentChannel(channel);
        ent.setEffectiveAt(Instant.now());
        ent.setUpdatedAt(Instant.now());
        membershipEntitlementRepository.save(ent);

        MembershipOrder order = MembershipOrder.builder()
                .orderNo("OS" + System.currentTimeMillis() + UUID.randomUUID().toString().replace("-", "").substring(0, 8).toUpperCase(Locale.ROOT))
                .user(user)
                .fromTier(OverseasMembershipTier.FREE.getCode())
                .toTier(tier.getCode())
                .payableAmountCent(0)
                .currency("USD")
                .channel(channel)
                .orderType(MembershipOrderType.TIER.name())
                .status(MembershipOrderStatus.GRANTED.name())
                .providerTradeId(externalRef)
                .providerPayload(payloadNote)
                .paidAt(Instant.now())
                .grantedAt(Instant.now())
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        membershipOrderRepository.save(order);
        log.info("overseas subscription granted userId={} tier={} until={}", userId, tier.getCode(), expiresAt);
    }

    private void downgradeToFree(Long userId) {
        membershipEntitlementRepository.findByUserId(userId).ifPresent(ent -> {
            ent.setTierCode(OverseasMembershipTier.FREE.getCode());
            ent.setDeviceLimit(3);
            ent.setSubscriptionExpiresAt(null);
            ent.setBillingPeriod(null);
            ent.setSubscriptionCancelAtPeriodEnd(null);
            ent.setStripeCustomerId(null);
            ent.setStripeSubscriptionId(null);
            ent.setPaymentChannel("FREE");
            ent.setIsLifetime(false);
            ent.setUpdatedAt(Instant.now());
            membershipEntitlementRepository.save(ent);
            log.info("overseas subscription cleared userId={}", userId);
        });
    }

    private void recordConflict(Long userId, String incomingChannel, String existingChannel,
                                String incomingTier, String existingTier,
                                Instant incomingExpiresAt, Instant existingExpiresAt,
                                String payloadNote) {
        try {
            String activeChannels = existingChannel + "," + incomingChannel;
            String excerpt = payloadNote == null
                    ? null
                    : payloadNote.length() > 1000 ? payloadNote.substring(0, 1000) : payloadNote;
            subscriptionConflictRepository.save(SubscriptionConflict.builder()
                    .userId(userId)
                    .detectedAt(Instant.now())
                    .activeChannels(activeChannels)
                    .incomingChannel(incomingChannel)
                    .existingChannel(existingChannel)
                    .incomingTier(incomingTier)
                    .existingTier(existingTier)
                    .incomingExpiresAt(incomingExpiresAt)
                    .existingExpiresAt(existingExpiresAt)
                    .payloadExcerpt(excerpt)
                    .build());
        } catch (Exception e) {
            log.warn("failed to record subscription conflict userId={} reason={}", userId, e.getMessage());
        }
    }

    private static String asString(Object v) {
        return v == null ? null : String.valueOf(v);
    }

    private static Long parseLongMs(Object v) {
        if (v == null) return null;
        if (v instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(v.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @Scheduled(fixedDelayString = "${app.membership.overseas.expire-scan-ms:60000}")
    @Transactional
    public void expireSubscriptionsPastDue() {
        if (!isEnabled()) {
            return;
        }
        Instant now = Instant.now();
        for (MembershipEntitlement e : membershipEntitlementRepository.findExpiredSubscriptions(now)) {
            downgradeToFree(e.getUser().getId());
        }
    }
}
