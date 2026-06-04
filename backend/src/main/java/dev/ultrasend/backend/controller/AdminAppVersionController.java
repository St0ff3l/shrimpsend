package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.AdminAppVersionResponse;
import dev.ultrasend.backend.dto.CreateAppVersionRequest;
import dev.ultrasend.backend.dto.UpdateAppVersionRequest;
import dev.ultrasend.backend.service.AdminAppVersionService;
import dev.ultrasend.backend.service.AdminAuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin/app-versions")
@RequiredArgsConstructor
public class AdminAppVersionController {

    private final AdminAuthService adminAuthService;
    private final AdminAppVersionService adminAppVersionService;

    @GetMapping
    public ResponseEntity<List<AdminAppVersionResponse>> list(Authentication auth) {
        adminAuthService.requireAdmin(auth);
        return ResponseEntity.ok(adminAppVersionService.listAll());
    }

    @PostMapping
    public ResponseEntity<AdminAppVersionResponse> create(Authentication auth,
                                                         @Valid @RequestBody CreateAppVersionRequest req) {
        adminAuthService.requireAdmin(auth);
        return ResponseEntity.ok(adminAppVersionService.create(req));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<AdminAppVersionResponse> update(Authentication auth,
                                                         @PathVariable("id") long id,
                                                         @RequestBody UpdateAppVersionRequest req) {
        adminAuthService.requireAdmin(auth);
        return ResponseEntity.ok(adminAppVersionService.update(id, req));
    }

    @PatchMapping("/{id}/publish-web")
    public ResponseEntity<AdminAppVersionResponse> publishWeb(Authentication auth,
                                                            @PathVariable("id") long id) {
        adminAuthService.requireAdmin(auth);
        return ResponseEntity.ok(adminAppVersionService.publishWeb(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(Authentication auth, @PathVariable("id") long id) {
        adminAuthService.requireAdmin(auth);
        adminAppVersionService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
