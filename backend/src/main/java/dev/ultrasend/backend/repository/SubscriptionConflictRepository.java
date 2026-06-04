package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.SubscriptionConflict;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SubscriptionConflictRepository extends JpaRepository<SubscriptionConflict, Long> {
    List<SubscriptionConflict> findByUserIdOrderByDetectedAtDesc(Long userId);
}
