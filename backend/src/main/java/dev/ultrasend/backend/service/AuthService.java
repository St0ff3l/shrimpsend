package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.AuthResponse;
import dev.ultrasend.backend.dto.LoginByCodeRequest;
import dev.ultrasend.backend.dto.LoginRequest;
import dev.ultrasend.backend.dto.RefreshRequest;
import dev.ultrasend.backend.dto.RegisterRequest;
import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.entity.EmailVerificationCode;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.DeviceRepository;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.security.AppJwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    public static final String SESSION_EXPIRED_MESSAGE = "登录已失效，请重新登录";

    private final UserRepository userRepository;
    private final DeviceRepository deviceRepository;
    private final DeviceService deviceService;
    private final PasswordEncoder passwordEncoder;
    private final AppJwtService jwtService;
    private final VerificationCodeService verificationCodeService;

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        boolean codeValid = verificationCodeService.verify(
                req.getEmail(), EmailVerificationCode.TYPE_REGISTER, req.getCode());
        if (!codeValid) {
            log.warn("register failed invalid code email={}", req.getEmail());
            throw new IllegalArgumentException("验证码错误或已过期");
        }
        if (userRepository.existsByEmail(req.getEmail())) {
            log.warn("register failed email already exists email={}", req.getEmail());
            throw new IllegalArgumentException("该邮箱已被注册");
        }
        String displayName = (req.getUsername() != null && !req.getUsername().isBlank())
                ? req.getUsername().trim()
                : req.getEmail().substring(0, req.getEmail().indexOf('@'));
        User user = User.builder()
                .email(req.getEmail().trim().toLowerCase())
                .username(displayName)
                .passwordHash(passwordEncoder.encode(req.getPassword()))
                .build();
        user = userRepository.save(user);
        String userId = user.getId().toString();
        log.info("register created user userId={}", userId);
        Device d = deviceService.bindDeviceForSuccessfulAuth(
                user.getId(), req.getDeviceId(), req.getPlatform(), displayName);
        String accessToken = jwtService.generateAccessToken(userId, user.getEmail(), d.getDeviceId(), d.getSessionVersion());
        String refreshToken = jwtService.generateRefreshToken(userId, d.getDeviceId(), d.getSessionVersion());
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .userId(userId)
                .expiresIn(jwtService.getAccessExpirationSeconds())
                .build();
    }

    @Transactional
    public AuthResponse login(LoginRequest req) {
        User user = userRepository.findByEmail(req.getEmail().trim().toLowerCase())
                .orElseThrow(() -> {
                    log.warn("login failed user not found email={}", req.getEmail());
                    return new IllegalArgumentException("邮箱或密码错误");
                });
        if (!passwordEncoder.matches(req.getPassword(), user.getPasswordHash())) {
            log.warn("login failed wrong password email={}", req.getEmail());
            throw new IllegalArgumentException("邮箱或密码错误");
        }
        deviceService.assertCanAuthenticateWithDevice(user.getId(), req.getDeviceId(), req.getPlatform());
        Device d = deviceService.bindDeviceForSuccessfulAuth(
                user.getId(), req.getDeviceId(), req.getPlatform(), null);
        String userId = user.getId().toString();
        log.info("login ok userId={}", userId);
        String accessToken = jwtService.generateAccessToken(userId, user.getEmail(), d.getDeviceId(), d.getSessionVersion());
        String refreshToken = jwtService.generateRefreshToken(userId, d.getDeviceId(), d.getSessionVersion());
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .userId(userId)
                .expiresIn(jwtService.getAccessExpirationSeconds())
                .build();
    }

    @Transactional
    public AuthResponse loginByCode(LoginByCodeRequest req) {
        boolean codeValid = verificationCodeService.verify(
                req.getEmail(), EmailVerificationCode.TYPE_LOGIN, req.getCode().trim());
        if (!codeValid) {
            log.warn("login-by-code failed invalid code email={}", req.getEmail());
            throw new IllegalArgumentException("验证码错误或已过期");
        }
        User user = userRepository.findByEmail(req.getEmail().trim().toLowerCase())
                .orElseThrow(() -> {
                    log.warn("login-by-code failed user not found email={}", req.getEmail());
                    return new IllegalArgumentException("该邮箱未注册");
                });
        deviceService.assertCanAuthenticateWithDevice(user.getId(), req.getDeviceId(), req.getPlatform());
        Device d = deviceService.bindDeviceForSuccessfulAuth(
                user.getId(), req.getDeviceId(), req.getPlatform(), null);
        String userId = user.getId().toString();
        log.info("login-by-code ok userId={}", userId);
        String accessToken = jwtService.generateAccessToken(userId, user.getEmail(), d.getDeviceId(), d.getSessionVersion());
        String refreshToken = jwtService.generateRefreshToken(userId, d.getDeviceId(), d.getSessionVersion());
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .userId(userId)
                .expiresIn(jwtService.getAccessExpirationSeconds())
                .build();
    }

    @Transactional
    public void logout(Long userId, String deviceId) {
        if (deviceId != null && !deviceId.isBlank()) {
            deviceService.unregister(userId, deviceId);
        }
        log.info("logout ok userId={}", userId);
    }

    @Transactional
    public AuthResponse refresh(RefreshRequest req) {
        AppJwtService.ParsedAuthToken parsed = jwtService.parseRefreshToken(req.getRefreshToken());
        String userId = parsed.userId();
        User user = userRepository.findById(Long.parseLong(userId))
                .orElseThrow(() -> {
                    log.warn("refresh failed user not found userId={}", userId);
                    return new ResponseStatusException(
                            HttpStatus.UNAUTHORIZED, SESSION_EXPIRED_MESSAGE);
                });
        log.info("refresh ok userId={}", userId);
        if (parsed.deviceId() != null && parsed.deviceSessionVersion() != null) {
            Device d = deviceRepository
                    .findByUser_IdAndDeviceIdAndActiveTrue(Long.parseLong(userId), parsed.deviceId())
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.UNAUTHORIZED, SESSION_EXPIRED_MESSAGE));
            if (d.getSessionVersion() != parsed.deviceSessionVersion()) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, SESSION_EXPIRED_MESSAGE);
            }
            String accessToken = jwtService.generateAccessToken(userId, user.getEmail(), d.getDeviceId(), d.getSessionVersion());
            String refreshToken = jwtService.generateRefreshToken(userId, d.getDeviceId(), d.getSessionVersion());
            return AuthResponse.builder()
                    .accessToken(accessToken)
                    .refreshToken(refreshToken)
                    .userId(userId)
                    .expiresIn(jwtService.getAccessExpirationSeconds())
                    .build();
        }
        String accessToken = jwtService.generateAccessToken(userId, user.getEmail());
        String refreshToken = jwtService.generateRefreshToken(userId);
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .userId(userId)
                .expiresIn(jwtService.getAccessExpirationSeconds())
                .build();
    }
}
