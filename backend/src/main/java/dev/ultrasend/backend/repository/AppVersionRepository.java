package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.AppVersion;

import java.util.List;
import java.util.Optional;

public interface AppVersionRepository extends org.springframework.data.jpa.repository.JpaRepository<AppVersion, Long> {

    Optional<AppVersion> findTopByEnabledTrueOrderByBuildNumberDesc();

    List<AppVersion> findAllByEnabledTrueOrderByBuildNumberDesc();

    Optional<AppVersion> findByBuildNumber(int buildNumber);

    List<AppVersion> findAllByOrderByBuildNumberDesc();

    Optional<AppVersion> findByWebPublishedTrue();
}
