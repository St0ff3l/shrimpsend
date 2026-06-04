package dev.ultrasend.backend.controller;

import com.stripe.Stripe;
import com.stripe.exception.EventDataObjectDeserializationException;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.Subscription;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import com.stripe.exception.StripeException;
import com.stripe.param.SubscriptionUpdateParams;
import com.stripe.param.checkout.SessionCreateParams;
import dev.ultrasend.backend.config.OverseasBillingProperties;
import dev.ultrasend.backend.service.ClusterDeploymentService;
import dev.ultrasend.backend.service.OverseasSubscriptionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/membership/stripe")
@RequiredArgsConstructor
@Slf4j
public class StripeMembershipController {

    private final OverseasBillingProperties overseasBillingProperties;
    private final ClusterDeploymentService clusterDeploymentService;
    private final OverseasSubscriptionService overseasSubscriptionService;

    @PostMapping("/create-checkout-session")
    public ResponseEntity<Map<String, String>> createCheckoutSession(
            Authentication auth,
            @RequestBody Map<String, String> body) {
        if (!clusterDeploymentService.isOverseasDeployment()) {
            throw new IllegalArgumentException("Stripe checkout仅适用于海外集群");
        }
        String priceId = body.getOrDefault("priceId", "").trim();
        if (priceId.isBlank()) {
            throw new IllegalArgumentException("priceId required");
        }
        long userId = Long.parseLong((String) auth.getPrincipal());
        overseasSubscriptionService.logStripePriceRequest("create-checkout-session", userId, priceId);
        if (overseasSubscriptionService.resolveStripePriceId(priceId).isEmpty()) {
            log.warn("stripe_price_unknown action=create-checkout-session userId={} incoming={} catalog={}",
                    userId, priceId, overseasSubscriptionService.stripePriceCatalogForLog());
            throw new IllegalArgumentException("未知 Stripe Price");
        }

        String secret = overseasBillingProperties.getStripeSecretKey();
        if (secret == null || secret.isBlank()) {
            throw new IllegalArgumentException("Stripe 未配置");
        }
        Stripe.apiKey = secret;

        overseasSubscriptionService.findStripeSubscriptionId(userId).ifPresent(sid -> {
            try {
                Subscription existing = Subscription.retrieve(sid);
                String st = existing.getStatus();
                if ("active".equals(st) || "trialing".equals(st) || "past_due".equals(st)) {
                    throw new IllegalArgumentException("已有 Stripe 订阅，请使用升级或管理订阅");
                }
            } catch (StripeException e) {
                log.warn("stripe checkout guard retrieve failed subId={} msg={}", sid, e.getMessage());
            }
        });

        // Allow caller to pass platform=desktop|web|ios|android so the success/cancel page can
        // render a "return to the app" hint when the user finished checkout from a desktop app.
        String platform = body.getOrDefault("platform", "web").trim().toLowerCase();
        String successUrl = appendQueryParams(
                overseasBillingProperties.getStripeSuccessUrl(),
                "session_id={CHECKOUT_SESSION_ID}",
                "platform=" + urlEncode(platform));
        String cancelUrl = appendQueryParams(
                overseasBillingProperties.getStripeCancelUrl(),
                "platform=" + urlEncode(platform));

        SessionCreateParams params = SessionCreateParams.builder()
                .setMode(SessionCreateParams.Mode.SUBSCRIPTION)
                .setSuccessUrl(successUrl)
                .setCancelUrl(cancelUrl)
                .addLineItem(SessionCreateParams.LineItem.builder()
                        .setPrice(priceId)
                        .setQuantity(1L)
                        .build())
                .setClientReferenceId(String.valueOf(userId))
                .setSubscriptionData(SessionCreateParams.SubscriptionData.builder()
                        .putMetadata("userId", String.valueOf(userId))
                        .putMetadata("checkoutPlatform", platform)
                        .build())
                .build();

        try {
            Session session = Session.create(params);
            Map<String, String> out = new HashMap<>();
            out.put("url", session.getUrl());
            return ResponseEntity.ok(out);
        } catch (Exception e) {
            log.warn("stripe checkout failed userId={} msg={}", userId, e.getMessage());
            throw new IllegalArgumentException("Stripe 下单失败");
        }
    }

    /**
     * Stripe Customer Portal（取消订阅、支付方式等）。需 Dashboard 中启用 Billing Portal。
     */
    @PostMapping("/billing-portal-session")
    public ResponseEntity<Map<String, String>> createBillingPortalSession(Authentication auth) {
        if (!clusterDeploymentService.isOverseasDeployment()) {
            throw new IllegalArgumentException("Stripe 仅适用于海外集群");
        }
        String secret = overseasBillingProperties.getStripeSecretKey();
        if (secret == null || secret.isBlank()) {
            throw new IllegalArgumentException("Stripe 未配置");
        }
        Stripe.apiKey = secret;
        long userId = Long.parseLong((String) auth.getPrincipal());
        String customerId = overseasSubscriptionService.findStripeCustomerId(userId)
                .orElseThrow(() -> new IllegalArgumentException("未找到 Stripe 客户，请先完成网页订阅"));
        String returnUrl = overseasBillingProperties.getStripeBillingPortalReturnUrl();
        if (returnUrl == null || returnUrl.isBlank()) {
            throw new IllegalArgumentException("Stripe Portal 回跳地址未配置");
        }
        try {
            com.stripe.param.billingportal.SessionCreateParams params =
                    com.stripe.param.billingportal.SessionCreateParams.builder()
                            .setCustomer(customerId)
                            .setReturnUrl(returnUrl)
                            .build();
            com.stripe.model.billingportal.Session session = com.stripe.model.billingportal.Session.create(params);
            Map<String, String> out = new HashMap<>();
            out.put("url", session.getUrl());
            return ResponseEntity.ok(out);
        } catch (StripeException e) {
            log.warn("stripe billing portal failed userId={} msg={}", userId, e.getMessage());
            throw new IllegalArgumentException("无法打开订阅管理");
        }
    }

    /**
     * 将现有 Stripe 订阅升级到更高档位 Price（比例折算计费）。
     */
    @PostMapping("/subscription/update-price")
    public ResponseEntity<Map<String, String>> updateSubscriptionPrice(
            Authentication auth,
            @RequestBody Map<String, String> body) {
        if (!clusterDeploymentService.isOverseasDeployment()) {
            throw new IllegalArgumentException("Stripe 仅适用于海外集群");
        }
        String priceId = body.getOrDefault("priceId", "").trim();
        if (priceId.isBlank()) {
            throw new IllegalArgumentException("priceId required");
        }
        String secret = overseasBillingProperties.getStripeSecretKey();
        if (secret == null || secret.isBlank()) {
            throw new IllegalArgumentException("Stripe 未配置");
        }
        Stripe.apiKey = secret;
        long userId = Long.parseLong((String) auth.getPrincipal());
        overseasSubscriptionService.logStripePriceRequest("subscription-update-price", userId, priceId);
        overseasSubscriptionService.validateStripeSubscriptionUpgrade(userId, priceId);
        String subId = overseasSubscriptionService.findStripeSubscriptionId(userId).orElseThrow();
        try {
            Subscription sub = Subscription.retrieve(subId);
            if (sub.getItems() == null || sub.getItems().getData().isEmpty()) {
                throw new IllegalArgumentException("Stripe 订阅缺少计费项");
            }
            // pending_if_incomplete 与 cancel_at_period_end 不得在同一 Subscription.update 里混用（Stripe API 限制）
            if (Boolean.TRUE.equals(sub.getCancelAtPeriodEnd())) {
                log.info("stripe upgrade step1 clear cancel_at_period_end subId={}", subId);
                sub = sub.update(SubscriptionUpdateParams.builder()
                        .setCancelAtPeriodEnd(false)
                        .build());
                if (sub.getItems() == null || sub.getItems().getData().isEmpty()) {
                    throw new IllegalArgumentException("Stripe 订阅缺少计费项");
                }
            }
            String itemId = sub.getItems().getData().get(0).getId();
            SubscriptionUpdateParams params = SubscriptionUpdateParams.builder()
                    .addItem(SubscriptionUpdateParams.Item.builder()
                            .setId(itemId)
                            .setPrice(priceId)
                            .build())
                    // 同周期换价时立刻生成发票并收款；create_prorations 不一定马上出账
                    .setProrationBehavior(SubscriptionUpdateParams.ProrationBehavior.ALWAYS_INVOICE)
                    .setPaymentBehavior(SubscriptionUpdateParams.PaymentBehavior.PENDING_IF_INCOMPLETE)
                    .build();
            Subscription updated = sub.update(params);
            // 避免「待支付 / 3DS」时已写入更高档位：只有 Stripe 侧订阅已是 active/trialing 才同步权益
            String payStatus = updated.getStatus();
            if (!"active".equals(payStatus) && !"trialing".equals(payStatus)) {
                log.warn("stripe upgrade deferred sync until paid status={} userId={}", payStatus, userId);
                throw new IllegalArgumentException(
                        "升级尚未完成扣款或发卡行验证；支付成功后 Stripe 会回调并同步权益，请勿重复提交");
            }
            syncStripeSubscription(updated);
            log.info(
                    "stripe upgrade invoiced userId={} subId={} latestInvoice={}",
                    userId,
                    updated.getId(),
                    updated.getLatestInvoice());
            Map<String, String> out = new HashMap<>();
            out.put("status", updated.getStatus() != null ? updated.getStatus() : "");
            return ResponseEntity.ok(out);
        } catch (StripeException e) {
            log.warn("stripe subscription update failed userId={} msg={}", userId, e.getMessage());
            throw new IllegalArgumentException("升级订阅失败: " + e.getMessage());
        }
    }

    @PostMapping("/webhook")
    public ResponseEntity<String> webhook(
            @RequestHeader(value = "Stripe-Signature", required = false) String sigHeader,
            @RequestBody String payload) {
        if (!clusterDeploymentService.isOverseasDeployment()) {
            log.info("stripe webhook action=ignored_not_overseas payloadBytes={}", payload != null ? payload.length() : 0);
            return ResponseEntity.ok("ignored");
        }
        String whSecret = overseasBillingProperties.getStripeWebhookSecret();
        if (whSecret == null || whSecret.isBlank()) {
            log.warn("stripe webhook secret not configured");
            return ResponseEntity.badRequest().body("no secret");
        }
        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, whSecret);
        } catch (SignatureVerificationException e) {
            log.warn("stripe webhook signature failed (check STRIPE_WEBHOOK_SECRET matches `stripe listen` output)");
            return ResponseEntity.badRequest().body("sig");
        }

        String apiKey = overseasBillingProperties.getStripeSecretKey();
        Stripe.apiKey = apiKey;
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("stripe STRIPE_SECRET_KEY not set; cannot retrieve subscription after checkout");
        }

        log.info(
                "stripe webhook received id={} type={} apiVersion={} livemode={} payloadBytes={}",
                event.getId(),
                event.getType(),
                event.getApiVersion(),
                event.getLivemode(),
                payload != null ? payload.length() : 0);

        try {
            switch (event.getType()) {
                case "checkout.session.completed" -> handleCheckoutCompleted(event);
                case "customer.subscription.updated" -> handleSubscriptionUpdated(event);
                case "customer.subscription.deleted" -> handleSubscriptionDeleted(event);
                default -> log.info("stripe webhook no-op for event type={}", event.getType());
            }
        } catch (Exception e) {
            log.warn("stripe webhook handle failed type={} msg={}", event.getType(), e.getMessage(), e);
            return ResponseEntity.internalServerError().body("err");
        }
        log.info("stripe webhook action=ok type={} id={}", event.getType(), event.getId());
        return ResponseEntity.ok("ok");
    }

    private void handleCheckoutCompleted(Event event) {
        Session session = (Session) deserializeDataObject(event);
        if (session == null) {
            log.warn("stripe checkout.session.completed missing payload object evt={}", event.getId());
            return;
        }
        String subId = session.getSubscription();
        log.info(
                "stripe checkout.session.completed sessionId={} mode={} customer={} subscription={} clientReferenceId={}",
                session.getId(),
                session.getMode(),
                session.getCustomer(),
                subId,
                session.getClientReferenceId());
        if (subId == null || subId.isBlank()) {
            log.warn("stripe checkout.session.completed has no subscription id session={} mode={}",
                    session.getId(), session.getMode());
            return;
        }
        try {
            Subscription sub = Subscription.retrieve(subId);
            log.info(
                    "stripe checkout.session.completed retrieved subId={} status={} userId={} priceId={} currentPeriodEnd={}",
                    sub.getId(),
                    sub.getStatus(),
                    parseUserId(sub),
                    sub.getItems() != null && !sub.getItems().getData().isEmpty()
                            ? sub.getItems().getData().get(0).getPrice().getId()
                            : null,
                    sub.getCurrentPeriodEnd());
            syncStripeSubscription(sub);
        } catch (Exception e) {
            log.warn("stripe checkout subscription retrieve failed {}", e.getMessage());
        }
    }

    private void handleSubscriptionUpdated(Event event) {
        Object o = deserializeDataObject(event);
        if (o instanceof Subscription sub) {
            log.info(
                    "stripe customer.subscription.updated subId={} status={} userId={} priceId={} cancelAtPeriodEnd={} currentPeriodEnd={}",
                    sub.getId(),
                    sub.getStatus(),
                    parseUserId(sub),
                    sub.getItems() != null && !sub.getItems().getData().isEmpty()
                            ? sub.getItems().getData().get(0).getPrice().getId()
                            : null,
                    sub.getCancelAtPeriodEnd(),
                    sub.getCurrentPeriodEnd());
            syncStripeSubscription(sub);
        } else {
            log.warn("stripe customer.subscription.updated unexpected payload type={} evt={}",
                    o != null ? o.getClass().getName() : "null", event.getId());
        }
    }

    private void handleSubscriptionDeleted(Event event) {
        Object o = deserializeDataObject(event);
        if (!(o instanceof Subscription sub)) {
            return;
        }
        Long userId = parseUserId(sub);
        log.info("stripe customer.subscription.deleted subId={} userId={} action=subscription_ended",
                sub.getId(), userId);
        if (userId != null) {
            overseasSubscriptionService.stripeSubscriptionEnded(userId);
        }
    }

    /**
     * Stripe CLI / live webhooks may use an API version newer than stripe-java's bundled models;
     * {@link com.stripe.model.EventDataObjectDeserializer#getObject()} can be empty while
     * {@link com.stripe.model.EventDataObjectDeserializer#deserializeUnsafe()} still works.
     */
    private static Object deserializeDataObject(Event event) {
        var deser = event.getDataObjectDeserializer();
        return deser.getObject().orElseGet(() -> {
            try {
                return deser.deserializeUnsafe();
            } catch (EventDataObjectDeserializationException e) {
                log.warn("stripe event object deserialize failed type={} evt={} msg={}",
                        event.getType(), event.getId(), e.getMessage());
                return null;
            }
        });
    }

    private void syncStripeSubscription(Subscription sub) {
        if (sub == null || sub.getItems() == null || sub.getItems().getData().isEmpty()) {
            log.warn("stripe subscription sync skipped: missing items subId={}",
                    sub != null ? sub.getId() : null);
            return;
        }
        String subscriptionStatus = sub.getStatus();
        if ("incomplete".equals(subscriptionStatus) || "incomplete_expired".equals(subscriptionStatus)) {
            log.warn("stripe subscription sync skipped unpaid status={} subId={}",
                    subscriptionStatus, sub.getId());
            return;
        }
        Long userId = parseUserId(sub);
        if (userId == null) {
            log.warn("stripe subscription missing userId metadata subId={}", sub.getId());
            return;
        }
        String priceId = sub.getItems().getData().get(0).getPrice().getId();
        long endSec = sub.getCurrentPeriodEnd();
        Instant end = Instant.ofEpochSecond(endSec);
        log.info(
                "stripe subscription sync userId={} subId={} customer={} priceId={} status={} periodEnd={} cancelAtPeriodEnd={}",
                userId,
                sub.getId(),
                sub.getCustomer(),
                priceId,
                subscriptionStatus,
                end,
                sub.getCancelAtPeriodEnd());
        overseasSubscriptionService.applyStripeSubscription(
                userId,
                sub.getId(),
                sub.getCustomer(),
                priceId,
                end,
                sub.toJson(),
                sub.getCancelAtPeriodEnd());
    }

    /**
     * Appends one or more {@code key=value} query string fragments to a URL, preserving any
     * existing query string. Empty fragments are skipped.
     */
    private static String appendQueryParams(String url, String... fragments) {
        if (url == null || url.isBlank() || fragments == null || fragments.length == 0) {
            return url;
        }
        StringBuilder sb = new StringBuilder(url);
        boolean hasQuery = url.contains("?");
        for (String f : fragments) {
            if (f == null || f.isBlank()) continue;
            sb.append(hasQuery ? '&' : '?').append(f);
            hasQuery = true;
        }
        return sb.toString();
    }

    private static String urlEncode(String v) {
        return java.net.URLEncoder.encode(v == null ? "" : v, java.nio.charset.StandardCharsets.UTF_8);
    }

    private static Long parseUserId(Subscription sub) {
        if (sub.getMetadata() == null || sub.getMetadata().get("userId") == null) {
            return null;
        }
        try {
            return Long.parseLong(sub.getMetadata().get("userId"));
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
