package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.MobileVerificationCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

public interface MobileVerificationCodeRepository extends JpaRepository<MobileVerificationCode, Long> {

    Optional<MobileVerificationCode> findFirstByMobileAndTypeAndUsedFalseAndExpiresAtAfterOrderByCreatedAtDesc(
            String mobile, String type, Instant now);

    long countByMobileAndTypeAndCreatedAtAfter(String mobile, String type, Instant after);

    void deleteByExpiresAtBefore(Instant time);
}
