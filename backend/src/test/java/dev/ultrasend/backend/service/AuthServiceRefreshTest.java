package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.RefreshRequest;
import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.DeviceRepository;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.security.AppJwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceRefreshTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private DeviceRepository deviceRepository;
    @Mock
    private DeviceService deviceService;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private VerificationCodeService verificationCodeService;

    private AppJwtService jwtService;
    private AuthService authService;

    @BeforeEach
    void setUp() {
        jwtService = new AppJwtService(
                "ultrasend-access-secret-change-in-production",
                900_000L,
                "ultrasend-refresh-secret-change-in-production",
                31_536_000_000L);
        authService = new AuthService(
                userRepository,
                deviceRepository,
                deviceService,
                passwordEncoder,
                jwtService,
                verificationCodeService);
    }

    @Test
    void refreshUnknownUserReturns401() {
        String refreshToken = jwtService.generateRefreshToken("42", "macos_dev", 1);
        when(userRepository.findById(42L)).thenReturn(Optional.empty());

        RefreshRequest req = new RefreshRequest();
        req.setRefreshToken(refreshToken);

        ResponseStatusException ex =
                assertThrows(ResponseStatusException.class, () -> authService.refresh(req));

        assertEquals(HttpStatus.UNAUTHORIZED, ex.getStatusCode());
        assertEquals(AuthService.SESSION_EXPIRED_MESSAGE, ex.getReason());
    }

    @Test
    void refreshInactiveDeviceReturns401() {
        User user = User.builder().id(7L).email("u@example.com").passwordHash("x").build();
        String refreshToken = jwtService.generateRefreshToken("7", "macos_dev", 1);
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(7L, "macos_dev"))
                .thenReturn(Optional.empty());

        RefreshRequest req = new RefreshRequest();
        req.setRefreshToken(refreshToken);

        ResponseStatusException ex =
                assertThrows(ResponseStatusException.class, () -> authService.refresh(req));

        assertEquals(HttpStatus.UNAUTHORIZED, ex.getStatusCode());
        assertEquals(AuthService.SESSION_EXPIRED_MESSAGE, ex.getReason());
    }

    @Test
    void refreshSessionVersionMismatchReturns401() {
        User user = User.builder().id(8L).email("u2@example.com").passwordHash("x").build();
        String refreshToken = jwtService.generateRefreshToken("8", "macos_dev", 1);
        Device device = Device.builder()
                .deviceId("macos_dev")
                .name("Mac")
                .sessionVersion(2)
                .active(true)
                .build();
        when(userRepository.findById(8L)).thenReturn(Optional.of(user));
        when(deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(8L, "macos_dev"))
                .thenReturn(Optional.of(device));

        RefreshRequest req = new RefreshRequest();
        req.setRefreshToken(refreshToken);

        ResponseStatusException ex =
                assertThrows(ResponseStatusException.class, () -> authService.refresh(req));

        assertEquals(HttpStatus.UNAUTHORIZED, ex.getStatusCode());
        assertEquals(AuthService.SESSION_EXPIRED_MESSAGE, ex.getReason());
    }
}
