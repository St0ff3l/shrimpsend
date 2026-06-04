package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.EmailVerificationCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

public interface EmailVerificationCodeRepository extends JpaRepository<EmailVerificationCode, Long> {

    Optional<EmailVerificationCode> findFirstByEmailAndTypeAndUsedFalseAndExpiresAtAfterOrderByCreatedAtDesc(
            String email, String type, Instant now);

    long countByEmailAndTypeAndCreatedAtAfter(String email, String type, Instant after);

    void deleteByExpiresAtBefore(Instant time);
}
