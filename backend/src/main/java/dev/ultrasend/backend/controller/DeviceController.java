package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.DeviceDto;
import dev.ultrasend.backend.dto.DevicePresenceRequest;
import dev.ultrasend.backend.dto.DeviceRegisterRequest;
import dev.ultrasend.backend.dto.DeviceUpdateRequest;
import dev.ultrasend.backend.service.DeviceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
@Slf4j
public class DeviceController {

    private final DeviceService deviceService;

    @PostMapping
    public ResponseEntity<DeviceDto> register(
            Authentication auth,
            @Valid @RequestBody DeviceRegisterRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("device register userId={} deviceId={}", userId, req.getDeviceId());
        DeviceDto dto = deviceService.register(userId, req);
        log.info("device register ok userId={} deviceId={}", userId, dto.getDeviceId());
        return ResponseEntity.ok(dto);
    }

    @PatchMapping("/{deviceId}")
    public ResponseEntity<DeviceDto> update(
            Authentication auth,
            @PathVariable String deviceId,
            @Valid @RequestBody DeviceUpdateRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("device update userId={} deviceId={}", userId, deviceId);
        DeviceDto dto = deviceService.update(userId, deviceId, req);
        return ResponseEntity.ok(dto);
    }

    @GetMapping
    public ResponseEntity<List<DeviceDto>> list(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("device list userId={}", userId);
        List<DeviceDto> list = deviceService.listByUser(userId);
        log.debug("device list userId={} count={}", userId, list.size());
        return ResponseEntity.ok(list);
    }

    @PostMapping("/{deviceId}/presence")
    public ResponseEntity<DeviceDto> updatePresence(
            Authentication auth,
            @PathVariable String deviceId,
            @Valid @RequestBody DevicePresenceRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        DeviceDto dto = deviceService.updatePresence(userId, deviceId, req);
        return ResponseEntity.ok(dto);
    }

    @DeleteMapping("/{deviceId}")
    public ResponseEntity<Void> unregister(Authentication auth, @PathVariable String deviceId) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("device unregister userId={} deviceId={}", userId, deviceId);
        deviceService.unregister(userId, deviceId);
        return ResponseEntity.noContent().build();
    }
}
