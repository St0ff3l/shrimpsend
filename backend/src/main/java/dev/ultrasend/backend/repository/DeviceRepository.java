package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.Device;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DeviceRepository extends org.springframework.data.jpa.repository.JpaRepository<Device, Long> {

    @Query("SELECT d.displayCode FROM Device d WHERE d.user.id = :userId AND d.displayCode IS NOT NULL")
    List<Integer> findUsedDisplayCodesByUserId(@Param("userId") Long userId);

    List<Device> findAllByUserId(Long userId);

    List<Device> findAllByUser_IdAndActiveTrue(Long userId);

    Optional<Device> findByUserIdAndDeviceId(Long userId, String deviceId);

    Optional<Device> findByUser_IdAndDeviceIdAndActiveTrue(Long userId, String deviceId);

    Optional<Device> findByDeviceId(String deviceId);

    void deleteByUserIdAndDeviceId(Long userId, String deviceId);

    long countByUserId(Long userId);

    long countByUser_IdAndActiveTrue(Long userId);
}
