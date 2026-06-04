package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.QrCreateResponse;
import dev.ultrasend.backend.dto.QrSessionRequest;
import dev.ultrasend.backend.dto.QrStatusResponse;
import dev.ultrasend.backend.service.QrAuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth/qr")
@RequiredArgsConstructor
@Slf4j
public class QrAuthController {

    private final QrAuthService qrAuthService;

    @PostMapping("/create")
    public ResponseEntity<QrCreateResponse> create() {
        String sessionId = qrAuthService.createSession();
        return ResponseEntity.ok(QrCreateResponse.builder().sessionId(sessionId).build());
    }

    @GetMapping("/status/{sessionId}")
    public ResponseEntity<QrStatusResponse> status(
            @PathVariable String sessionId,
            @RequestParam(required = false) String deviceId,
            @RequestParam(required = false) String platform) {
        QrStatusResponse res = qrAuthService.getStatus(sessionId, deviceId, platform);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/scan")
    public ResponseEntity<Void> scan(@Valid @RequestBody QrSessionRequest req) {
        Long userId = getAuthenticatedUserId();
        qrAuthService.scan(req.getSessionId(), userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/confirm")
    public ResponseEntity<Void> confirm(@Valid @RequestBody QrSessionRequest req) {
        Long userId = getAuthenticatedUserId();
        qrAuthService.confirm(req.getSessionId(), userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/cancel")
    public ResponseEntity<Void> cancel(@Valid @RequestBody QrSessionRequest req) {
        Long userId = getAuthenticatedUserId();
        qrAuthService.cancel(req.getSessionId(), userId);
        return ResponseEntity.ok().build();
    }

    private Long getAuthenticatedUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) {
            throw new org.springframework.security.authentication.AuthenticationCredentialsNotFoundException("未登录");
        }
        return Long.parseLong(auth.getPrincipal().toString());
    }
}
