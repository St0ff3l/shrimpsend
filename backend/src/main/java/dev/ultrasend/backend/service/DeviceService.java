package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.DeviceDto;
import dev.ultrasend.backend.dto.DevicePresenceRequest;
import dev.ultrasend.backend.dto.DeviceRegisterRequest;
import dev.ultrasend.backend.dto.DeviceUpdateRequest;
import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.entity.DevicePresenceSession;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.DevicePresenceSessionRepository;
import dev.ultrasend.backend.repository.DeviceRepository;
import dev.ultrasend.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class DeviceService {

    public static final String DEVICE_LIMIT_AUTH_MESSAGE =
            "当前账号可绑定设备数量已达上限，请开通会员或增购设备后再登录。";
    public static final String DEVICE_LIMIT_REGISTER_MESSAGE =
            "当前会员最多绑定 %d 台设备，请升级会员后再添加";

    private final DeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final MembershipService membershipService;
    private final DeviceRosterPublisher deviceRosterPublisher;
    private final DevicePresenceSessionRepository devicePresenceSessionRepository;

    @Value("${app.device-presence.stale-sec:180}")
    private long presenceStaleSec;

    public static final String PRESENCE_ONLINE = "online";
    public static final String PRESENCE_OFFLINE = "offline";

    /**
     * 会员名额：只计「非 Web 活跃设备数」+「若存在任一 Web 活跃设备则 +1」。
     * Web 可绑定多台浏览器（多条 device 记录），统计上始终只占 1 个名额；下线仅由用户主动登出/删除设备触发。
     */
    public int countEffectiveDevicesForLimit(Long userId) {
        List<Device> active = deviceRepository.findAllByUser_IdAndActiveTrue(userId);
        long nonWeb = active.stream()
                .filter(d -> d.getPlatform() == null || !"web".equalsIgnoreCase(d.getPlatform()))
                .count();
        long web = active.stream()
                .filter(d -> d.getPlatform() != null && "web".equalsIgnoreCase(d.getPlatform()))
                .count();
        return (int) (nonWeb + Math.min(1, web));
    }

    /**
     * 登录/发验证码前校验：新绑定是否会使有效占用超过上限（在已有 Web 时再绑一台 Web 不增加有效占用）。
     */
    public void assertCanAuthenticateWithDevice(Long userId, String deviceId, String platform) {
        if (deviceId == null || deviceId.isBlank()) {
            throw new IllegalArgumentException("请更新应用到最新版本后再登录");
        }
        Device existing = deviceRepository.findByDeviceId(deviceId).orElse(null);
        if (existing != null) {
            if (!existing.getUser().getId().equals(userId)) {
                ensureCanAddDevice(userId, platformForLimitCheck(platform, existing.getPlatform()));
                return;
            }
            // 同用户：inactive 设备即将在 bind 中被激活，会新增有效占用，须校验（与 register 一致）
            if (!existing.isActive()) {
                ensureCanAddDevice(userId, platformForLimitCheck(platform, existing.getPlatform()));
                return;
            }
            log.debug(
                    "device limit assert skipped: same user re-auth (no new slot) userId={} deviceId={}",
                    userId,
                    deviceId);
            return;
        }
        ensureCanAddDevice(userId, platform);
    }

    /**
     * 登录/注册成功后绑定设备并返回用于签发 JWT 的会话版本。
     */
    @Transactional
    public Device bindDeviceForSuccessfulAuth(Long userId, String deviceId, String platform, String defaultName) {
        User user = userRepository.findById(userId).orElseThrow();
        Device device = deviceRepository.findByDeviceId(deviceId).orElse(null);
        Instant now = Instant.now();
        if (device == null) {
            ensureCanAddDevice(userId, platform);
            String name = (defaultName != null && !defaultName.isBlank()) ? defaultName : "Device";
            device = Device.builder()
                    .deviceId(deviceId)
                    .user(user)
                    .name(name)
                    .platform(platform)
                    .active(true)
                    .sessionVersion(0)
                    .lastSeen(now)
                    .presenceStatus(PRESENCE_ONLINE)
                    .presenceUpdatedAt(now)
                    .build();
            ensureDisplayCode(device, userId);
            device = deviceRepository.save(device);
            log.info("device auth bind created userId={} deviceId={}", userId, deviceId);
            deviceRosterPublisher.publishUpsertAfterCommit(userId, toDto(device));
            return device;
        }
        if (!device.getUser().getId().equals(userId)) {
            ensureCanAddDevice(userId, platformForLimitCheck(platform, device.getPlatform()));
            Long oldUid = device.getUser().getId();
            device.setDisplayCode(null);
            device.setUser(user);
            device.setActive(true);
            devicePresenceSessionRepository.closeOpenSessionsForDevice(oldUid, device.getDeviceId(), now);
            bumpSessionVersion(device);
            if (platform != null) {
                device.setPlatform(platform);
            }
            if (defaultName != null && !defaultName.isBlank()) {
                device.setName(defaultName);
            }
            device.setLastSeen(now);
            markDevicePresence(device, PRESENCE_ONLINE, now);
            ensureDisplayCode(device, userId);
            device = deviceRepository.save(device);
            log.info("device auth bind transferred userId={} deviceId={} fromUserId={}", userId, deviceId, oldUid);
            deviceRosterPublisher.publishRemoveAfterCommit(oldUid, device.getDeviceId());
            deviceRosterPublisher.publishUpsertAfterCommit(userId, toDto(device));
            return device;
        }
        // 同用户：inactive → active 会新增有效占用（扫码/密码/验证码登录均走此路径）
        if (!device.isActive()) {
            ensureCanAddDevice(userId, platformForLimitCheck(platform, device.getPlatform()));
        }
        device.setActive(true);
        bumpSessionVersion(device);
        if (platform != null) {
            device.setPlatform(platform);
        }
        if (defaultName != null && !defaultName.isBlank()) {
            device.setName(defaultName);
        }
        device.setLastSeen(now);
        markDevicePresence(device, PRESENCE_ONLINE, now);
        ensureDisplayCode(device, userId);
        device = deviceRepository.save(device);
        log.info("device auth bind refreshed userId={} deviceId={}", userId, deviceId);
        deviceRosterPublisher.publishUpsertAfterCommit(userId, toDto(device));
        return device;
    }

    @Transactional
    public DeviceDto register(Long userId, DeviceRegisterRequest req) {
        User user = userRepository.findById(userId).orElseThrow();
        Device device = deviceRepository.findByDeviceId(req.getDeviceId()).orElse(null);
        String action;
        Long previousUserId = null;
        if (device == null) {
            ensureCanAddDevice(userId, req.getPlatform());
            device = Device.builder()
                    .deviceId(req.getDeviceId())
                    .user(user)
                    .active(true)
                    .sessionVersion(0)
                    .build();
            action = "created";
        } else if (!device.getUser().getId().equals(userId)) {
            // 换绑到当前用户：一律按当前用户名额校验（与设备此前归属无关）
            ensureCanAddDevice(userId, platformForLimitCheck(req.getPlatform(), device.getPlatform()));
            Long oldUserId = device.getUser().getId();
            previousUserId = oldUserId;
            device.setDisplayCode(null);
            device.setUser(user);
            device.setActive(true);
            devicePresenceSessionRepository.closeOpenSessionsForDevice(oldUserId, device.getDeviceId(), Instant.now());
            bumpSessionVersion(device);
            action = "switched from userId=" + oldUserId;
        } else {
            // 同用户：inactive → active 会新增有效占用，须校验；已活跃则仅更新资料
            if (!device.isActive()) {
                ensureCanAddDevice(userId, platformForLimitCheck(req.getPlatform(), device.getPlatform()));
            }
            device.setActive(true);
            // 同用户周期性 register 仅更新资料，不递增 sessionVersion，避免使当前 JWT 失效
            action = "updated";
        }
        device.setName(req.getName());
        if (req.getPlatform() != null) {
            device.setPlatform(req.getPlatform());
        }
        device.setLanHttpUrl(req.getLanHttpUrl());
        Instant now = Instant.now();
        device.setLastSeen(now);
        markDevicePresence(device, PRESENCE_ONLINE, now);
        if (device.isActive()) {
            ensureDisplayCode(device, userId);
        }
        device = deviceRepository.save(device);
        touchPresenceSession(userId, device.getDeviceId(), req.getSessionId(), device.getPlatform(), now);
        log.info("device register {} userId={} deviceId={}", action, userId, device.getDeviceId());
        DeviceDto dto = toDto(device);
        if (previousUserId != null) {
            deviceRosterPublisher.publishRemoveAfterCommit(previousUserId, device.getDeviceId());
        }
        deviceRosterPublisher.publishUpsertAfterCommit(userId, dto);
        return dto;
    }

    /**
     * 新增一条设备绑定时是否允许：非 Web 或「首台 Web」会使有效占用 +1；在已有 Web 时再绑 Web 不增加有效占用。
     * platform 为 null 时按非 Web 处理。
     */
    private void ensureCanAddDevice(Long userId, String platform) {
        int limit = membershipService.resolveDeviceLimitForUser(userId);
        int eff = countEffectiveDevicesForLimit(userId);
        boolean hasWeb = hasActiveWebDevice(userId);
        boolean isWeb = platform != null && "web".equalsIgnoreCase(platform);
        boolean increasesEff = !isWeb || !hasWeb;
        if (increasesEff && eff >= limit) {
            throw new IllegalArgumentException(String.format(DEVICE_LIMIT_REGISTER_MESSAGE, limit));
        }
    }

    private boolean hasActiveWebDevice(Long userId) {
        return deviceRepository.findAllByUser_IdAndActiveTrue(userId).stream()
                .anyMatch(d -> d.getPlatform() != null && "web".equalsIgnoreCase(d.getPlatform()));
    }

    private void bumpSessionVersion(Device d) {
        d.setSessionVersion(d.getSessionVersion() + 1);
    }

    /**
     * 换绑/登录时额度校验使用的平台：与 bind/register 写入一致，优先本次请求中的 platform。
     */
    private static String platformForLimitCheck(String requestPlatform, String storedPlatform) {
        if (requestPlatform != null && !requestPlatform.isBlank()) {
            return requestPlatform.trim();
        }
        return storedPlatform;
    }

    @Transactional
    public DeviceDto update(Long userId, String deviceId, DeviceUpdateRequest req) {
        Device device = deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(userId, deviceId)
                .orElseThrow(() -> {
                    log.warn("device update not found userId={} deviceId={}", userId, deviceId);
                    return new IllegalArgumentException("Device not found");
                });
        if (req.getName() != null) {
            device.setName(req.getName());
        }
        if (req.getLanHttpUrl() != null) {
            device.setLanHttpUrl(req.getLanHttpUrl());
        }
        device.setLastSeen(Instant.now());
        device = deviceRepository.save(device);
        log.info("device update ok userId={} deviceId={}", userId, deviceId);
        DeviceDto dto = toDto(device);
        deviceRosterPublisher.publishUpsertAfterCommit(userId, dto);
        return dto;
    }

    public List<DeviceDto> listByUser(Long userId) {
        List<DeviceDto> list = deviceRepository.findAllByUser_IdAndActiveTrue(userId).stream()
                .map(this::toDto)
                .collect(Collectors.toList());
        log.debug("device listByUser userId={} count={}", userId, list.size());
        return list;
    }

    @Transactional
    public void unregister(Long userId, String deviceId) {
        deviceRepository.findByUserIdAndDeviceId(userId, deviceId).ifPresent(d -> {
            d.setActive(false);
            d.setDisplayCode(null);
            markDevicePresence(d, PRESENCE_OFFLINE, Instant.now());
            bumpSessionVersion(d);
            deviceRepository.save(d);
            devicePresenceSessionRepository.closeOpenSessionsForDevice(userId, deviceId, Instant.now());
            log.info("device unregister (inactive) userId={} deviceId={}", userId, deviceId);
            deviceRosterPublisher.publishRemoveAfterCommit(userId, deviceId);
        });
    }

    @Transactional
    public void updateLastSeen(Long userId, String deviceId) {
        deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(userId, deviceId).ifPresent(d -> {
            Instant now = Instant.now();
            d.setLastSeen(now);
            boolean changed = markDevicePresence(d, PRESENCE_ONLINE, now);
            deviceRepository.save(d);
            if (changed) {
                deviceRosterPublisher.publishUpsertAfterCommit(userId, toDto(d));
            }
        });
    }

    @Transactional
    public DeviceDto updatePresence(Long userId, String deviceId, DevicePresenceRequest req) {
        String status = req.getStatus() == null ? "" : req.getStatus().trim().toLowerCase();
        if (PRESENCE_ONLINE.equals(status)) {
            return markOnline(userId, deviceId, req.getSessionId(), req.getPlatform());
        }
        if (PRESENCE_OFFLINE.equals(status)) {
            return closePresenceSession(userId, deviceId, req.getSessionId());
        }
        throw new IllegalArgumentException("Unsupported presence status");
    }

    @Transactional
    public DeviceDto markOnline(Long userId, String deviceId, String sessionId, String platform) {
        Device device = deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(userId, deviceId)
                .orElseThrow(() -> new IllegalArgumentException("Device not found"));
        Instant now = Instant.now();
        device.setLastSeen(now);
        boolean changed = markDevicePresence(device, PRESENCE_ONLINE, now);
        touchPresenceSession(userId, deviceId, sessionId, platformForLimitCheck(platform, device.getPlatform()), now);
        device = deviceRepository.save(device);
        DeviceDto dto = toDto(device);
        if (changed) {
            deviceRosterPublisher.publishUpsertAfterCommit(userId, dto);
        }
        return dto;
    }

    @Transactional
    public void touchOnline(Long userId, String deviceId, String sessionId, String platform) {
        deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(userId, deviceId).ifPresent(d -> {
            Instant now = Instant.now();
            d.setLastSeen(now);
            boolean changed = markDevicePresence(d, PRESENCE_ONLINE, now);
            touchPresenceSession(userId, deviceId, sessionId, platformForLimitCheck(platform, d.getPlatform()), now);
            deviceRepository.save(d);
            if (changed) {
                deviceRosterPublisher.publishUpsertAfterCommit(userId, toDto(d));
            }
        });
    }

    @Transactional
    public DeviceDto closePresenceSession(Long userId, String deviceId, String sessionId) {
        Device device = deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(userId, deviceId)
                .orElseThrow(() -> new IllegalArgumentException("Device not found"));
        Instant now = Instant.now();
        if (sessionId != null && !sessionId.isBlank()) {
            devicePresenceSessionRepository
                    .findByUserIdAndDeviceIdAndSessionId(userId, deviceId, sessionId.trim())
                    .ifPresent(session -> {
                        session.setClosedAt(now);
                        devicePresenceSessionRepository.save(session);
                    });
        }
        device = aggregateDevicePresence(device, now);
        device = deviceRepository.save(device);
        return toDto(device);
    }

    @Transactional
    @Scheduled(fixedDelayString = "${app.device-presence.sweep-delay-ms:30000}")
    public int closeStalePresenceSessions() {
        Instant now = Instant.now();
        Instant cutoff = now.minusSeconds(presenceStaleSec);
        List<DevicePresenceSession> stale = devicePresenceSessionRepository.findAllByClosedAtIsNullAndLastSeenBefore(cutoff);
        if (stale.isEmpty()) {
            return 0;
        }
        Set<AffectedPresenceDevice> affected = new HashSet<>();
        for (DevicePresenceSession session : stale) {
            session.setClosedAt(now);
            affected.add(new AffectedPresenceDevice(session.getUserId(), session.getDeviceId()));
        }
        devicePresenceSessionRepository.saveAll(stale);
        for (AffectedPresenceDevice affectedDevice : affected) {
            deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(
                    affectedDevice.userId(),
                    affectedDevice.deviceId()).ifPresent(device -> {
                Device updated = aggregateDevicePresence(device, now);
                deviceRepository.save(updated);
            });
        }
        return stale.size();
    }

    private void touchPresenceSession(Long userId, String deviceId, String sessionId, String platform, Instant now) {
        if (sessionId == null || sessionId.isBlank()) {
            return;
        }
        devicePresenceSessionRepository.upsertOpenSession(
                userId, deviceId, sessionId.trim(), platform, now);
    }

    private Device aggregateDevicePresence(Device device, Instant now) {
        Instant cutoff = now.minusSeconds(presenceStaleSec);
        boolean hasActiveSession = devicePresenceSessionRepository
                .existsByUserIdAndDeviceIdAndClosedAtIsNullAndLastSeenAfter(
                        device.getUser().getId(),
                        device.getDeviceId(),
                        cutoff);
        String nextStatus = hasActiveSession ? PRESENCE_ONLINE : PRESENCE_OFFLINE;
        boolean changed = markDevicePresence(device, nextStatus, now);
        if (changed) {
            deviceRosterPublisher.publishUpsertAfterCommit(device.getUser().getId(), toDto(device));
        }
        return device;
    }

    private boolean markDevicePresence(Device device, String status, Instant now) {
        String current = device.getPresenceStatus();
        if (current == null || current.isBlank()) {
            current = PRESENCE_OFFLINE;
        }
        if (current.equals(status)) {
            return false;
        }
        device.setPresenceStatus(status);
        device.setPresenceUpdatedAt(now);
        return true;
    }

    private record AffectedPresenceDevice(Long userId, String deviceId) {}

    private DeviceDto toDto(Device d) {
        Long lastSeenMs = d.getLastSeen() != null ? d.getLastSeen().toEpochMilli() : null;
        Long presenceUpdatedAtMs = d.getPresenceUpdatedAt() != null ? d.getPresenceUpdatedAt().toEpochMilli() : null;
        return DeviceDto.builder()
                .displayCode(d.getDisplayCode())
                .deviceId(d.getDeviceId())
                .name(d.getName())
                .platform(d.getPlatform())
                .lanHttpUrl(d.getLanHttpUrl())
                .lastSeen(lastSeenMs)
                .presenceStatus(d.getPresenceStatus() == null ? PRESENCE_OFFLINE : d.getPresenceStatus())
                .presenceUpdatedAt(presenceUpdatedAtMs)
                .build();
    }

    private static final int DISPLAY_CODE_MAX = 999;

    private void ensureDisplayCode(Device device, Long userId) {
        if (!device.isActive()) {
            return;
        }
        if (device.getDisplayCode() != null) {
            return;
        }
        device.setDisplayCode(nextDisplayCode(userId));
    }

    private int nextDisplayCode(Long userId) {
        List<Integer> used = deviceRepository.findUsedDisplayCodesByUserId(userId);
        Set<Integer> taken = new HashSet<>(used);
        for (int i = 1; i <= DISPLAY_CODE_MAX; i++) {
            if (!taken.contains(i)) {
                return i;
            }
        }
        throw new IllegalArgumentException(
                "设备展示号码已用尽（每账号最多 " + DISPLAY_CODE_MAX + " 台）");
    }
}
