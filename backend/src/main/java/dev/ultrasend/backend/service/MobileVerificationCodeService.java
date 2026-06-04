package dev.ultrasend.backend.service;

import dev.ultrasend.backend.entity.MobileVerificationCode;
import dev.ultrasend.backend.repository.MobileVerificationCodeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class MobileVerificationCodeService {

    private static final int CODE_LENGTH = 6;
    private static final long CODE_TTL_MINUTES = 10;
    private static final long RATE_LIMIT_WINDOW_MINUTES = 10;
    private static final long RATE_LIMIT_MAX = 5;

    private final MobileVerificationCodeRepository codeRepo;
    private final TencentSmsService smsService;
    private final SecureRandom random = new SecureRandom();

    @Transactional
    public void sendCode(String mobile, String type) {
        String normalizedMobile = normalizeMobile(mobile);

        long recentCount = codeRepo.countByMobileAndTypeAndCreatedAtAfter(
                normalizedMobile, type,
                Instant.now().minus(RATE_LIMIT_WINDOW_MINUTES, ChronoUnit.MINUTES));
        if (recentCount >= RATE_LIMIT_MAX) {
            throw new IllegalArgumentException("发送过于频繁，请稍后再试");
        }

        String code = generateCode();
        Instant now = Instant.now();
        MobileVerificationCode entity = MobileVerificationCode.builder()
                .mobile(normalizedMobile)
                .code(code)
                .type(type)
                .createdAt(now)
                .expiresAt(now.plus(CODE_TTL_MINUTES, ChronoUnit.MINUTES))
                .used(false)
                .build();
        codeRepo.save(entity);
        log.info("mobile verification code created mobile={} type={} code={} expiresAt={}", 
                normalizedMobile, type, code, entity.getExpiresAt());

        try {
            smsService.sendVerificationCode(normalizedMobile, code);
            log.info("mobile verification code sent successfully mobile={} type={} code={}", 
                    normalizedMobile, type, code);
        } catch (Exception e) {
            log.error("mobile verification code send failed mobile={} type={} code={}", 
                    normalizedMobile, type, code, e);
            throw e;
        }
    }

    public boolean verify(String mobile, String type, String code) {
        String normalizedMobile = normalizeMobile(mobile);
        var optCode = codeRepo.findFirstByMobileAndTypeAndUsedFalseAndExpiresAtAfterOrderByCreatedAtDesc(
                normalizedMobile, type, Instant.now());
        if (optCode.isEmpty()) {
            return false;
        }
        MobileVerificationCode entity = optCode.get();
        if (!entity.getCode().equals(code)) {
            return false;
        }
        entity.setUsed(true);
        codeRepo.save(entity);
        log.info("mobile verification code verified mobile={} type={}", normalizedMobile, type);
        return true;
    }

    @Scheduled(fixedRate = 3600_000)
    @Transactional
    public void cleanupExpired() {
        codeRepo.deleteByExpiresAtBefore(Instant.now().minus(1, ChronoUnit.HOURS));
    }

    private String generateCode() {
        int num = random.nextInt(1_000_000);
        return String.format("%06d", num);
    }

    private String normalizeMobile(String mobile) {
        return mobile.trim().replaceAll("[^0-9]", "");
    }
}
