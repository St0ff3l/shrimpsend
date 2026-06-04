package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.ChangePasswordRequest;
import dev.ultrasend.backend.dto.ConfirmDeleteAccountRequest;
import dev.ultrasend.backend.dto.UserProfileResponse;
import dev.ultrasend.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
@Slf4j
public class UserController {

    private final UserService userService;

    @GetMapping("/profile")
    public ResponseEntity<UserProfileResponse> getProfile(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("getProfile userId={}", userId);
        return ResponseEntity.ok(userService.getProfile(userId));
    }

    @PostMapping("/send-change-password-code")
    public ResponseEntity<Void> sendChangePasswordCode(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("sendChangePasswordCode userId={}", userId);
        userService.sendChangePasswordCode(userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/change-password")
    public ResponseEntity<Void> changePassword(Authentication auth,
                                                @Valid @RequestBody ChangePasswordRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("changePassword userId={}", userId);
        userService.changePassword(userId, req);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/send-delete-code")
    public ResponseEntity<Void> sendDeleteCode(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("sendDeleteCode userId={}", userId);
        userService.sendDeleteAccountCode(userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/confirm-delete-account")
    public ResponseEntity<Void> confirmDeleteAccount(Authentication auth,
                                                      @Valid @RequestBody ConfirmDeleteAccountRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("confirmDeleteAccount userId={}", userId);
        userService.confirmDeleteAccount(userId, req.getCode());
        return ResponseEntity.ok().build();
    }
}
