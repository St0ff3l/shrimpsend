package dev.ultrasend.backend.service;

import dev.ultrasend.backend.entity.EmailVerificationCode;
import dev.ultrasend.backend.repository.EmailVerificationCodeRepository;
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
public class VerificationCodeService {

    private static final int CODE_LENGTH = 6;
    private static final long CODE_TTL_MINUTES = 10;
    private static final long RATE_LIMIT_WINDOW_MINUTES = 10;
    private static final long RATE_LIMIT_MAX = 5;

    private final EmailVerificationCodeRepository codeRepo;
    private final SendCloudMailService mailService;
    private final SecureRandom random = new SecureRandom();

    @Transactional
    public void sendCode(String email, String type) {
        String normalizedEmail = email.trim().toLowerCase();

        long recentCount = codeRepo.countByEmailAndTypeAndCreatedAtAfter(
                normalizedEmail, type,
                Instant.now().minus(RATE_LIMIT_WINDOW_MINUTES, ChronoUnit.MINUTES));
        if (recentCount >= RATE_LIMIT_MAX) {
            throw new IllegalArgumentException("发送过于频繁，请稍后再试");
        }

        String code = generateCode();
        Instant now = Instant.now();
        EmailVerificationCode entity = EmailVerificationCode.builder()
                .email(normalizedEmail)
                .code(code)
                .type(type)
                .createdAt(now)
                .expiresAt(now.plus(CODE_TTL_MINUTES, ChronoUnit.MINUTES))
                .used(false)
                .build();
        codeRepo.save(entity);
        log.info("verification code created email={} type={}", normalizedEmail, type);

        mailService.sendVerificationCode(normalizedEmail, code);
    }

    public boolean verify(String email, String type, String code) {
        String normalizedEmail = email.trim().toLowerCase();
        var optCode = codeRepo.findFirstByEmailAndTypeAndUsedFalseAndExpiresAtAfterOrderByCreatedAtDesc(
                normalizedEmail, type, Instant.now());
        if (optCode.isEmpty()) {
            return false;
        }
        EmailVerificationCode entity = optCode.get();
        if (!entity.getCode().equals(code)) {
            return false;
        }
        entity.setUsed(true);
        codeRepo.save(entity);
        log.info("verification code verified email={} type={}", normalizedEmail, type);
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
}
