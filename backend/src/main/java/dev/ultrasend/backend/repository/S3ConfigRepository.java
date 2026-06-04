package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.S3Config;

import java.util.Optional;

public interface S3ConfigRepository extends org.springframework.data.jpa.repository.JpaRepository<S3Config, Long> {

    Optional<S3Config> findByUserId(Long userId);
}
