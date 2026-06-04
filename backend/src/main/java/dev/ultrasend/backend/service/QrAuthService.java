package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.QrStatusResponse;
import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.entity.QrLoginSession;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.QrLoginSessionRepository;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.security.AppJwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class QrAuthService {

    private static final long SESSION_TTL_MINUTES = 5;

    private final QrLoginSessionRepository qrRepo;
    private final UserRepository userRepository;
    private final AppJwtService jwtService;
    private final DeviceService deviceService;

    public String createSession() {
        String sessionId = UUID.randomUUID().toString();
        Instant now = Instant.now();
        QrLoginSession session = QrLoginSession.builder()
                .sessionId(sessionId)
                .status(QrLoginSession.STATUS_PENDING)
                .createdAt(now)
                .expiresAt(now.plus(SESSION_TTL_MINUTES, ChronoUnit.MINUTES))
                .build();
        qrRepo.save(session);
        log.info("qr session created sessionId={}", sessionId);
        return sessionId;
    }

    @Transactional
    public QrStatusResponse getStatus(String sessionId, String deviceId, String platform) {
        QrLoginSession session = qrRepo.findBySessionId(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("二维码会话不存在"));

        if (isExpired(session) && !QrLoginSession.STATUS_CONSUMED.equals(session.getStatus())
                && !QrLoginSession.STATUS_CANCELLED.equals(session.getStatus())) {
            session.setStatus(QrLoginSession.STATUS_EXPIRED);
            qrRepo.save(session);
        }

        if (QrLoginSession.STATUS_CONFIRMED.equals(session.getStatus())) {
            if (deviceId == null || deviceId.isBlank()) {
                throw new IllegalArgumentException("请更新应用到最新版本后再登录");
            }
            User user = userRepository.findById(session.getUserId())
                    .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
            String userId = user.getId().toString();
            deviceService.assertCanAuthenticateWithDevice(user.getId(), deviceId, platform);
            Device d = deviceService.bindDeviceForSuccessfulAuth(user.getId(), deviceId, platform, null);
            String accessToken = jwtService.generateAccessToken(userId, user.getEmail(), d.getDeviceId(), d.getSessionVersion());
            String refreshToken = jwtService.generateRefreshToken(userId, d.getDeviceId(), d.getSessionVersion());

            session.setStatus(QrLoginSession.STATUS_CONSUMED);
            qrRepo.save(session);

            log.info("qr session consumed sessionId={} userId={}", sessionId, userId);
            return QrStatusResponse.builder()
                    .status(QrLoginSession.STATUS_CONFIRMED)
                    .accessToken(accessToken)
                    .refreshToken(refreshToken)
                    .userId(userId)
                    .expiresIn(jwtService.getAccessExpirationSeconds())
                    .build();
        }

        return QrStatusResponse.builder()
                .status(session.getStatus())
                .build();
    }

    @Transactional
    public void scan(String sessionId, Long userId) {
        QrLoginSession session = qrRepo.findBySessionId(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("二维码会话不存在"));
        if (isExpired(session)) {
            session.setStatus(QrLoginSession.STATUS_EXPIRED);
            qrRepo.save(session);
            throw new IllegalArgumentException("二维码已过期");
        }
        if (!QrLoginSession.STATUS_PENDING.equals(session.getStatus())) {
            throw new IllegalArgumentException("二维码状态异常: " + session.getStatus());
        }
        session.setUserId(userId);
        session.setStatus(QrLoginSession.STATUS_SCANNED);
        qrRepo.save(session);
        log.info("qr session scanned sessionId={} userId={}", sessionId, userId);
    }

    @Transactional
    public void confirm(String sessionId, Long userId) {
        QrLoginSession session = qrRepo.findBySessionId(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("二维码会话不存在"));
        if (isExpired(session)) {
            session.setStatus(QrLoginSession.STATUS_EXPIRED);
            qrRepo.save(session);
            throw new IllegalArgumentException("二维码已过期");
        }
        if (!QrLoginSession.STATUS_SCANNED.equals(session.getStatus())) {
            throw new IllegalArgumentException("二维码状态异常: " + session.getStatus());
        }
        if (!userId.equals(session.getUserId())) {
            throw new IllegalArgumentException("无权操作此二维码会话");
        }
        session.setStatus(QrLoginSession.STATUS_CONFIRMED);
        qrRepo.save(session);
        log.info("qr session confirmed sessionId={} userId={}", sessionId, userId);
    }

    @Transactional
    public void cancel(String sessionId, Long userId) {
        QrLoginSession session = qrRepo.findBySessionId(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("二维码会话不存在"));
        if (!userId.equals(session.getUserId())) {
            throw new IllegalArgumentException("无权操作此二维码会话");
        }
        session.setStatus(QrLoginSession.STATUS_CANCELLED);
        qrRepo.save(session);
        log.info("qr session cancelled sessionId={} userId={}", sessionId, userId);
    }

    @Scheduled(fixedRate = 600_000)
    @Transactional
    public void cleanupExpired() {
        qrRepo.deleteByExpiresAtBefore(Instant.now().minus(10, ChronoUnit.MINUTES));
    }

    private boolean isExpired(QrLoginSession session) {
        return Instant.now().isAfter(session.getExpiresAt());
    }
}
