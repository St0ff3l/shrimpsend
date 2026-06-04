package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.DevicePresenceSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface DevicePresenceSessionRepository extends JpaRepository<DevicePresenceSession, Long> {

    Optional<DevicePresenceSession> findByUserIdAndDeviceIdAndSessionId(
            Long userId,
            String deviceId,
            String sessionId);

    boolean existsByUserIdAndDeviceIdAndClosedAtIsNullAndLastSeenAfter(
            Long userId,
            String deviceId,
            Instant cutoff);

    List<DevicePresenceSession> findAllByClosedAtIsNullAndLastSeenBefore(Instant cutoff);

    @Modifying
    @Query("""
            update DevicePresenceSession s
               set s.closedAt = :closedAt
             where s.userId = :userId
               and s.deviceId = :deviceId
               and s.closedAt is null
            """)
    int closeOpenSessionsForDevice(
            @Param("userId") Long userId,
            @Param("deviceId") String deviceId,
            @Param("closedAt") Instant closedAt);
}
