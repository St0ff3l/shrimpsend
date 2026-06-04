package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.MembershipOrderEvent;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MembershipOrderEventRepository extends JpaRepository<MembershipOrderEvent, Long> {
    boolean existsByProviderAndEventUniqueKey(String provider, String eventUniqueKey);
}
