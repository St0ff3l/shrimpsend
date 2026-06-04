package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.MembershipOrder;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MembershipOrderRepository extends JpaRepository<MembershipOrder, Long> {
    Optional<MembershipOrder> findByOrderNo(String orderNo);

    Optional<MembershipOrder> findTopByUserIdAndToTierAndChannelAndStatusOrderByCreatedAtDesc(
            Long userId,
            String toTier,
            String channel,
            String status
    );

    java.util.List<MembershipOrder> findAllByStatus(String status);
}
