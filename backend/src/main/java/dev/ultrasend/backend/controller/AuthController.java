package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.AuthResponse;
import dev.ultrasend.backend.dto.LoginByCodeRequest;
import dev.ultrasend.backend.dto.LoginRequest;
import dev.ultrasend.backend.dto.LogoutRequest;
import dev.ultrasend.backend.dto.RefreshRequest;
import dev.ultrasend.backend.dto.RegisterRequest;
import dev.ultrasend.backend.dto.SendCodeRequest;
import dev.ultrasend.backend.entity.EmailVerificationCode;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.service.AuthService;
import dev.ultrasend.backend.service.DeviceService;
import dev.ultrasend.backend.service.VerificationCodeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
public class AuthController {

    private final AuthService authService;
    private final VerificationCodeService verificationCodeService;
    private final UserRepository userRepository;
    private final DeviceService deviceService;

    @PostMapping("/send-code")
    public ResponseEntity<Void> sendCode(@Valid @RequestBody SendCodeRequest req) {
        log.info("send-code request email={} type={}", req.getEmail(), req.getType());
        String type = req.getType();
        if (type == null || type.isBlank()) {
            type = EmailVerificationCode.TYPE_REGISTER;
        } else if (!EmailVerificationCode.TYPE_REGISTER.equals(type) && !EmailVerificationCode.TYPE_LOGIN.equals(type)) {
            throw new IllegalArgumentException("type 只能为 REGISTER 或 LOGIN");
        }
        if (EmailVerificationCode.TYPE_LOGIN.equals(type)) {
            if (req.getDeviceId() == null || req.getDeviceId().isBlank()) {
                throw new IllegalArgumentException("请更新应用到最新版本后再登录");
            }
            userRepository.findByEmail(req.getEmail().trim().toLowerCase())
                    .ifPresent(u -> deviceService.assertCanAuthenticateWithDevice(
                            u.getId(), req.getDeviceId(), req.getPlatform()));
        }
        verificationCodeService.sendCode(req.getEmail(), type);
        log.info("send-code success email={}", req.getEmail());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest req) {
        log.info("register request email={}", req.getEmail());
        AuthResponse res = authService.register(req);
        log.info("register success userId={}", res.getUserId());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest req) {
        log.info("login request email={}", req.getEmail());
        AuthResponse res = authService.login(req);
        log.info("login success userId={}", res.getUserId());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/login-by-code")
    public ResponseEntity<AuthResponse> loginByCode(@Valid @RequestBody LoginByCodeRequest req) {
        log.info("login-by-code request email={}", req.getEmail());
        AuthResponse res = authService.loginByCode(req);
        log.info("login-by-code success userId={}", res.getUserId());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(@Valid @RequestBody RefreshRequest req) {
        log.info("refresh request");
        AuthResponse res = authService.refresh(req);
        log.info("refresh success userId={}", res.getUserId());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(Authentication auth, @RequestBody(required = false) LogoutRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        String deviceId = req != null ? req.getDeviceId() : null;
        log.info("logout request userId={} deviceId={}", userId, deviceId);
        authService.logout(userId, deviceId);
        return ResponseEntity.ok().build();
    }
}
