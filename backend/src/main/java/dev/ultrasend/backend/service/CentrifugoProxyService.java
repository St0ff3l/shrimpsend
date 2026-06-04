package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.DeviceRegisterRequest;
import dev.ultrasend.backend.dto.centrifugo.ConnectResultDto;
import dev.ultrasend.backend.dto.centrifugo.ConnectResponseDto;
import dev.ultrasend.backend.dto.centrifugo.RefreshResponseDto;
import dev.ultrasend.backend.dto.centrifugo.RefreshResultDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Centrifugo connect/refresh 代理：在 connect 时注册设备并缓存 clientId 映射，
 * 在 refresh 时更新 last_seen。不再主动踢设备下线。
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CentrifugoProxyService {

    private final DeviceService deviceService;

    @Value("${centrifugo.proxy.connection-expire-sec:120}")
    private long connectionExpireSec;

    @Value("${centrifugo.proxy.last-seen-write-interval-sec:45}")
    private long lastSeenWriteIntervalSec;

    /** clientId -> ClientInfo 的内存缓存，替代 web_connection 表 */
    private final ConcurrentHashMap<String, ClientInfo> clientCache = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long> lastSeenWriteAtByDevice = new ConcurrentHashMap<>();

    /**
     * 处理 connect proxy：注册设备并缓存 clientId 与 userId/deviceId 的映射。
     */
    public ConnectResponseDto handleConnect(
            String clientId,
            String userId,
            String deviceId,
            String name,
            String platform,
            String sessionId) {
        Long uid = Long.parseLong(userId);
        long expireAt = Instant.now().getEpochSecond() + connectionExpireSec;

        if (deviceId != null && !deviceId.isBlank()) {
            DeviceRegisterRequest req = new DeviceRegisterRequest();
            req.setDeviceId(deviceId.trim());
            req.setName(name != null && !name.isBlank() ? name.trim() : "Web");
            req.setPlatform(platform);
            req.setSessionId(sessionId);
            deviceService.register(uid, req);

            clientCache.put(clientId, new ClientInfo(uid, req.getDeviceId(), sessionId, platform));
            log.info("centrifugo connect proxy clientId={} userId={} deviceId={}", clientId, userId, req.getDeviceId());
        } else {
            log.debug("centrifugo connect proxy clientId={} userId={} no deviceId, skip cache", clientId, userId);
        }

        ConnectResultDto result = ConnectResultDto.builder()
                .user(userId)
                .expireAt(expireAt)
                .build();
        return ConnectResponseDto.builder().result(result).build();
    }

    /**
     * 处理 refresh proxy：从内存缓存中查找 clientId 对应的设备并更新 last_seen，返回新的 expire_at。
     */
    public RefreshResponseDto handleRefresh(String clientId) {
        long expireAt = Instant.now().getEpochSecond() + connectionExpireSec;
        ClientInfo info = clientCache.get(clientId);
        if (info != null) {
            maybeUpdateLastSeen(info);
        }
        return RefreshResponseDto.builder()
                .result(RefreshResultDto.builder().expireAt(expireAt).build())
                .build();
    }

    private void maybeUpdateLastSeen(ClientInfo info) {
        long now = Instant.now().getEpochSecond();
        String key = info.userId + ":" + info.deviceId;
        Long previous = lastSeenWriteAtByDevice.get(key);
        if (previous != null && now - previous < lastSeenWriteIntervalSec) {
            return;
        }
        lastSeenWriteAtByDevice.put(key, now);
        deviceService.touchOnline(info.userId, info.deviceId, info.sessionId, info.platform);
    }

    /**
     * 处理 disconnect proxy：仅清理内存缓存，不再 unregister 设备。
     */
    public void handleDisconnect(String clientId) {
        ClientInfo removed = clientCache.remove(clientId);
        if (removed != null) {
            log.info("centrifugo disconnect proxy: removed cache entry clientId={} deviceId={}", clientId, removed.deviceId);
        }
    }

    private record ClientInfo(Long userId, String deviceId, String sessionId, String platform) {}
}
