package dev.ultrasend.backend.service;

import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.entity.DevicePresenceSession;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.DevicePresenceSessionRepository;
import dev.ultrasend.backend.repository.DeviceRepository;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DeviceServiceTest {

    @Mock
    private DeviceRepository deviceRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private MembershipService membershipService;
    @Mock
    private DeviceRosterPublisher deviceRosterPublisher;
    @Mock
    private DevicePresenceSessionRepository devicePresenceSessionRepository;

    private DeviceService deviceService;

    @BeforeEach
    void setUp() {
        deviceService = new DeviceService(
                deviceRepository,
                userRepository,
                membershipService,
                deviceRosterPublisher,
                devicePresenceSessionRepository);
        ReflectionTestUtils.setField(deviceService, "presenceStaleSec", 180L);
    }

    @Test
    void closingOneWebSessionKeepsDeviceOnlineWhenAnotherSessionIsActive() {
        Device device = onlineDevice();
        when(deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(1L, "web_1"))
                .thenReturn(Optional.of(device));
        when(devicePresenceSessionRepository.findByUserIdAndDeviceIdAndSessionId(1L, "web_1", "tab_a"))
                .thenReturn(Optional.of(session("tab_a")));
        when(devicePresenceSessionRepository.existsByUserIdAndDeviceIdAndClosedAtIsNullAndLastSeenAfter(
                eq(1L), eq("web_1"), any(Instant.class)))
                .thenReturn(true);
        when(deviceRepository.save(any(Device.class))).thenAnswer(invocation -> invocation.getArgument(0));

        deviceService.closePresenceSession(1L, "web_1", "tab_a");

        verify(deviceRosterPublisher, never()).publishUpsertAfterCommit(any(), any());
        verify(deviceRepository).save(argThat(d -> DeviceService.PRESENCE_ONLINE.equals(d.getPresenceStatus())));
    }

    @Test
    void closingLastWebSessionMarksDeviceOfflineAndPublishesPatch() {
        Device device = onlineDevice();
        when(deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(1L, "web_1"))
                .thenReturn(Optional.of(device));
        when(devicePresenceSessionRepository.findByUserIdAndDeviceIdAndSessionId(1L, "web_1", "tab_a"))
                .thenReturn(Optional.of(session("tab_a")));
        when(devicePresenceSessionRepository.existsByUserIdAndDeviceIdAndClosedAtIsNullAndLastSeenAfter(
                eq(1L), eq("web_1"), any(Instant.class)))
                .thenReturn(false);
        when(deviceRepository.save(any(Device.class))).thenAnswer(invocation -> invocation.getArgument(0));

        deviceService.closePresenceSession(1L, "web_1", "tab_a");

        verify(deviceRepository).save(argThat(d -> DeviceService.PRESENCE_OFFLINE.equals(d.getPresenceStatus())));
        verify(deviceRosterPublisher).publishUpsertAfterCommit(eq(1L), any());
    }

    private static Device onlineDevice() {
        User user = new User();
        user.setId(1L);
        return Device.builder()
                .deviceId("web_1")
                .name("Web")
                .platform("web")
                .active(true)
                .user(user)
                .lastSeen(Instant.now())
                .presenceStatus(DeviceService.PRESENCE_ONLINE)
                .presenceUpdatedAt(Instant.now())
                .build();
    }

    private static DevicePresenceSession session(String sessionId) {
        return DevicePresenceSession.builder()
                .userId(1L)
                .deviceId("web_1")
                .sessionId(sessionId)
                .createdAt(Instant.now())
                .lastSeen(Instant.now())
                .build();
    }
}
