package dev.ultrasend.backend.service;

import dev.ultrasend.backend.centrifugo.CentrifugoPublishService;
import dev.ultrasend.backend.dto.DeviceDto;
import jakarta.annotation.PreDestroy;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class DeviceRosterPublisher {

    public static final String EVENT_TYPE = "device_roster_patch";
    private static final long DEBOUNCE_MS = 250L;

    private final CentrifugoPublishService centrifugoPublishService;
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "device-roster-publisher");
        t.setDaemon(true);
        return t;
    });
    private final ConcurrentHashMap<String, PendingPatch> pending = new ConcurrentHashMap<>();

    public void publishUpsertAfterCommit(Long userId, DeviceDto device) {
        if (userId == null || device == null || device.getDeviceId() == null) return;
        afterCommit(() -> enqueue(new PendingPatch(userId, "upsert", device.getDeviceId(), device)));
    }

    public void publishRemoveAfterCommit(Long userId, String deviceId) {
        if (userId == null || deviceId == null || deviceId.isBlank()) return;
        afterCommit(() -> enqueue(new PendingPatch(userId, "remove", deviceId, null)));
    }

    private void afterCommit(Runnable runnable) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    runnable.run();
                }
            });
            return;
        }
        runnable.run();
    }

    private void enqueue(PendingPatch patch) {
        String key = patch.userId + ":" + patch.deviceId;
        pending.put(key, patch);
        scheduler.schedule(() -> flush(key), DEBOUNCE_MS, TimeUnit.MILLISECONDS);
    }

    private void flush(String key) {
        PendingPatch patch = pending.remove(key);
        if (patch == null) return;
        Map<String, Object> payload = Map.of(
                "type", EVENT_TYPE,
                "action", patch.action,
                "deviceId", patch.deviceId,
                "device", patch.device == null ? Map.of() : patch.device,
                "updatedAtMs", Instant.now().toEpochMilli());
        try {
            centrifugoPublishService.publishToUser(patch.userId.toString(), payload);
        } catch (Exception e) {
            log.warn("device roster publish failed userId={} deviceId={} action={}: {}",
                    patch.userId, patch.deviceId, patch.action, e.getMessage());
        }
    }

    @PreDestroy
    public void shutdown() {
        scheduler.shutdownNow();
    }

    private record PendingPatch(Long userId, String action, String deviceId, DeviceDto device) {}
}
