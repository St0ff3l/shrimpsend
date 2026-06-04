package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.QrLoginSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

public interface QrLoginSessionRepository extends JpaRepository<QrLoginSession, Long> {

    Optional<QrLoginSession> findBySessionId(String sessionId);

    void deleteByExpiresAtBefore(Instant time);
}
