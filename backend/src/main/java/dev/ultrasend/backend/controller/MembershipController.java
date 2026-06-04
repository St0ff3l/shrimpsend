package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.entity.MobileVerificationCode;
import dev.ultrasend.backend.membership.MembershipTier;
import dev.ultrasend.backend.service.AlipaySignatureService;
import dev.ultrasend.backend.service.MembershipMigrationService;
import dev.ultrasend.backend.service.MembershipService;
import dev.ultrasend.backend.service.MobileVerificationCodeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/membership")
@RequiredArgsConstructor
@Slf4j
public class MembershipController {

    private final MembershipService membershipService;
    private final AlipaySignatureService alipaySignatureService;
    private final MobileVerificationCodeService mobileVerificationCodeService;
    
    private final MembershipMigrationService membershipMigrationService;

    @GetMapping("/tiers")
    public ResponseEntity<List<MembershipTierDto>> tiers() {
        return ResponseEntity.ok(membershipService.listTiers());
    }

    @GetMapping("/me")
    public ResponseEntity<MembershipMeResponse> me(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        return ResponseEntity.ok(membershipService.getMyMembership(userId));
    }

    @GetMapping("/cross-platform-hint")
    public ResponseEntity<CrossPlatformHintResponse> crossPlatformHint(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        return ResponseEntity.ok(membershipService.getCrossPlatformHint(userId));
    }

    @PostMapping("/orders")
    public ResponseEntity<MembershipCreateOrderResponse> createOrder(
            Authentication auth,
            @Valid @RequestBody MembershipCreateOrderRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        MembershipCreateOrderResponse resp = membershipService.createOrder(userId, req);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/orders/{orderNo}")
    public ResponseEntity<MembershipOrderResponse> getOrder(
            Authentication auth,
            @PathVariable String orderNo) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        return ResponseEntity.ok(membershipService.getOrder(userId, orderNo));
    }

    @PostMapping("/alipay/create")
    public ResponseEntity<MembershipAlipayCreateResponse> createAlipay(
            Authentication auth,
            @Valid @RequestBody MembershipAlipayCreateRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        return ResponseEntity.ok(membershipService.createAlipayPayUrl(userId, req.getOrderNo()));
    }

    /**
     * 支付宝异步通知。须返回纯文本 {@code success} / {@code failure}（HTTP 200），否则支付宝会重试。
     * 网关若报 502，多为反代到上游超时/连不上 JVM，而非本方法返回体格式问题。
     */
    @PostMapping(value = "/alipay/notify")
    public ResponseEntity<String> alipayNotify(@RequestParam MultiValueMap<String, String> form) {
        try {
            Map<String, String> params = form.toSingleValueMap();
            String orderNoProbe = params.get("out_trade_no");
            log.info("alipay notify received params={}", sanitizeAlipayParams(params));
            if (!alipaySignatureService.verifyNotifySignature(params)) {
                log.warn("alipay notify signature failed outTradeNo={}", orderNoProbe);
                return textAlipayBody("failure");
            }
            String orderNo = params.get("out_trade_no");
            String tradeNo = params.get("trade_no");
            if (orderNo == null || orderNo.isBlank()) {
                log.warn("alipay notify missing out_trade_no");
                return textAlipayBody("failure");
            }
            if (tradeNo == null || tradeNo.isBlank()) {
                log.warn("alipay notify missing trade_no orderNo={}", orderNo);
                return textAlipayBody("failure");
            }
            String amountText = params.getOrDefault("total_amount", "0");
            int amountCent;
            try {
                amountCent = new BigDecimal(amountText.trim())
                        .multiply(BigDecimal.valueOf(100))
                        .setScale(0, RoundingMode.HALF_UP)
                        .intValueExact();
            } catch (RuntimeException ex) {
                log.warn("alipay notify invalid total_amount orderNo={} total_amount={}", orderNo, amountText, ex);
                return textAlipayBody("failure");
            }
            log.info(
                    "alipay notify verified orderNo={} tradeNo={} tradeStatus={} totalAmount={} amountCent={} buyerId={} sellerId={} gmtPayment={} appId={}",
                    orderNo,
                    tradeNo,
                    params.get("trade_status"),
                    amountText,
                    amountCent,
                    params.get("buyer_id"),
                    params.get("seller_id"),
                    params.get("gmt_payment"),
                    params.get("app_id"));
            String payload = params.entrySet().stream()
                    .map(e -> e.getKey() + "=" + (e.getValue() == null ? "" : e.getValue()))
                    .collect(Collectors.joining("&"));
            boolean granted = membershipService.processAlipayPaid(orderNo, tradeNo, amountCent, payload);
            log.info(
                    "alipay notify response=success orderNo={} tradeNo={} result={}",
                    orderNo,
                    tradeNo,
                    granted ? "granted" : "duplicate");
            return textAlipayBody("success");
        } catch (Exception e) {
            log.error("alipay notify unexpected error", e);
            log.info("alipay notify response=failure reason={}", e.getMessage());
            return textAlipayBody("failure");
        }
    }

    private static Map<String, String> sanitizeAlipayParams(Map<String, String> params) {
        Map<String, String> sanitized = new LinkedHashMap<>();
        params.forEach((key, value) -> {
            if (!"sign".equals(key) && !"sign_type".equals(key)) {
                sanitized.put(key, value);
            }
        });
        return sanitized;
    }

    private static ResponseEntity<String> textAlipayBody(String body) {
        return ResponseEntity.ok()
                .contentType(MediaType.TEXT_PLAIN)
                .body(body);
    }

    @PostMapping("/revenuecat/webhook")
    public ResponseEntity<Map<String, Object>> revenueCatWebhook(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody Map<String, Object> payload) {
        log.info("revenuecat webhook received authPresent={} payload={}", authorization != null, payload);
        boolean changed = membershipService.processRevenueCatWebhook(payload, authorization);
        log.info("revenuecat webhook processed changed={}", changed);
        return ResponseEntity.ok(Map.of("ok", true, "changed", changed));
    }

    @PostMapping("/migration/send-code")
    public ResponseEntity<Void> sendMigrationCode(@Valid @RequestBody MembershipMigrationSendCodeRequest req) {
        log.info("membership migration send-code request mobile={}", req.getMobile());
        mobileVerificationCodeService.sendCode(req.getMobile(), MobileVerificationCode.TYPE_MIGRATION);
        log.info("membership migration send-code success mobile={}", req.getMobile());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/migration/verify")
    public ResponseEntity<MembershipMigrationVerifyResponse> verifyMigration(
            Authentication auth,
            @Valid @RequestBody MembershipMigrationVerifyRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("membership migration verify request userId={} mobile={}", userId, req.getMobile());
        try {
            boolean verified = membershipMigrationService.verifyMobile(userId, req.getMobile(), req.getCode());
            if (!verified) {
                MembershipMigrationVerifyResponse response = MembershipMigrationVerifyResponse.builder()
                        .success(false)
                        .message("验证码错误或已过期")
                        .build();
                return ResponseEntity.ok(response);
            }
            MembershipTier proTier = MembershipTier.PRO;
            MembershipMigrationVerifyResponse response = MembershipMigrationVerifyResponse.builder()
                    .success(true)
                    .message("验证成功，请确认迁移")
                    .tierCode(proTier.getCode())
                    .tierName(proTier.getDisplayName())
                    .deviceLimit(proTier.getDeviceLimit())
                    .build();
            log.info("membership migration verify success userId={} mobile={}", userId, req.getMobile());
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            log.warn("membership migration verify failed userId={} mobile={} reason={}", 
                    userId, req.getMobile(), e.getMessage());
            MembershipMigrationVerifyResponse response = MembershipMigrationVerifyResponse.builder()
                    .success(false)
                    .message(e.getMessage())
                    .build();
            return ResponseEntity.ok(response);
        }
    }

    @PostMapping("/migration/grant")
    public ResponseEntity<MembershipMigrationVerifyResponse> grantMigration(
            Authentication auth,
            @Valid @RequestBody MembershipMigrationGrantRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("membership migration grant request userId={} mobile={}", userId, req.getMobile());
        try {
            membershipMigrationService.grantProMembership(userId, req.getMobile());
            MembershipTier proTier = MembershipTier.PRO;
            MembershipMigrationVerifyResponse response = MembershipMigrationVerifyResponse.builder()
                    .success(true)
                    .message("会员迁移成功")
                    .tierCode(proTier.getCode())
                    .tierName(proTier.getDisplayName())
                    .deviceLimit(proTier.getDeviceLimit())
                    .build();
            log.info("membership migration grant success userId={} mobile={}", userId, req.getMobile());
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            log.warn("membership migration grant failed userId={} mobile={} reason={}", 
                    userId, req.getMobile(), e.getMessage());
            MembershipMigrationVerifyResponse response = MembershipMigrationVerifyResponse.builder()
                    .success(false)
                    .message(e.getMessage())
                    .build();
            return ResponseEntity.ok(response);
        }
    }
}
