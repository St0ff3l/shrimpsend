package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.MembershipEntitlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface MembershipEntitlementRepository extends JpaRepository<MembershipEntitlement, Long> {
    Optional<MembershipEntitlement> findByUserId(Long userId);

    @Query("SELECT e FROM MembershipEntitlement e WHERE e.subscriptionExpiresAt IS NOT NULL AND e.subscriptionExpiresAt < :now AND e.tierCode <> 'FREE'")
    List<MembershipEntitlement> findExpiredSubscriptions(@Param("now") Instant now);
}
