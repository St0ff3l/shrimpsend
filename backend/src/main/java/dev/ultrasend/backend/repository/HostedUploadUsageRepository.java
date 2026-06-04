package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.HostedUploadUsage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface HostedUploadUsageRepository extends JpaRepository<HostedUploadUsage, Long> {

    Optional<HostedUploadUsage> findByUserIdAndYearMonth(Long userId, String yearMonth);
}
