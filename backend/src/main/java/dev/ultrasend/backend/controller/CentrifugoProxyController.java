package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.centrifugo.ConnectRequestDto;
import dev.ultrasend.backend.dto.centrifugo.ConnectResponseDto;
import dev.ultrasend.backend.dto.centrifugo.DisconnectDto;
import dev.ultrasend.backend.dto.centrifugo.RefreshRequestDto;
import dev.ultrasend.backend.dto.centrifugo.RefreshResponseDto;
import dev.ultrasend.backend.dto.centrifugo.RefreshResultDto;
import dev.ultrasend.backend.service.CentrifugoProxyService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Centrifugo connect / refresh 代理接口。
 * Connect：由 Centrifugo 调用并转发客户端 Authorization，需已鉴权；注册设备。
 * Refresh：由 Centrifugo 周期性调用，无需用户 JWT，仅根据 client 更新 last_seen。
 * Disconnect：由 Centrifugo 连接断开时调用，仅清理内存缓存。
 */
@RestController
@RequestMapping("/api/centrifugo/proxy")
@RequiredArgsConstructor
@Slf4j
public class CentrifugoProxyController {

    private final CentrifugoProxyService centrifugoProxyService;

    @PostMapping(value = "/connect", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<ConnectResponseDto> connect(
            Authentication auth,
            @RequestBody ConnectRequestDto req) {
        if (auth == null || !auth.isAuthenticated()) {
            log.warn("centrifugo proxy connect unauthenticated");
            ConnectResponseDto disconnect = ConnectResponseDto.builder()
                    .disconnect(DisconnectDto.builder().code(4501).reason("unauthorized").build())
                    .build();
            return ResponseEntity.ok(disconnect);
        }
        String userId = (String) auth.getPrincipal();
        String clientId = req.getClient();
        if (clientId == null || clientId.isBlank()) {
            log.warn("centrifugo proxy connect missing client");
            ConnectResponseDto disconnect = ConnectResponseDto.builder()
                    .disconnect(DisconnectDto.builder().code(4500).reason("missing client").build())
                    .build();
            return ResponseEntity.ok(disconnect);
        }
        String deviceId = null;
        String name = null;
        String platform = null;
        String sessionId = null;
        if (req.getData() != null) {
            Object did = req.getData().get("deviceId");
            Object n = req.getData().get("name");
            Object p = req.getData().get("platform");
            Object sid = req.getData().get("sessionId");
            if (did != null) {
                deviceId = did.toString();
            }
            if (n != null) {
                name = n.toString();
            }
            if (p != null) {
                platform = p.toString();
            }
            if (sid != null) {
                sessionId = sid.toString();
            }
        }
        ConnectResponseDto response = centrifugoProxyService.handleConnect(clientId, userId, deviceId, name, platform, sessionId);
        return ResponseEntity.ok(response);
    }

    @PostMapping(value = "/refresh", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<RefreshResponseDto> refresh(@RequestBody RefreshRequestDto req) {
        String clientId = req.getClient();
        if (clientId == null || clientId.isBlank()) {
            log.warn("centrifugo proxy refresh missing client");
            return ResponseEntity.ok(RefreshResponseDto.builder()
                    .result(RefreshResultDto.builder()
                            .expireAt(java.time.Instant.now().getEpochSecond() + 120)
                            .build())
                    .build());
        }
        RefreshResponseDto response = centrifugoProxyService.handleRefresh(clientId);
        return ResponseEntity.ok(response);
    }

    @PostMapping(value = "/disconnect", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> disconnect(@RequestBody RefreshRequestDto req) {
        String clientId = req.getClient();
        if (clientId != null && !clientId.isBlank()) {
            centrifugoProxyService.handleDisconnect(clientId);
        }
        return ResponseEntity.ok(Map.of("result", Map.of()));
    }
}
