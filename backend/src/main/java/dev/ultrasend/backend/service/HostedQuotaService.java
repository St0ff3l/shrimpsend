package dev.ultrasend.backend.service;

import dev.ultrasend.backend.entity.MembershipEntitlement;
import dev.ultrasend.backend.membership.OverseasMembershipTier;
import dev.ultrasend.backend.repository.HostedUploadUsageRepository;
import dev.ultrasend.backend.repository.MembershipEntitlementRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
public class HostedQuotaService {

    private final ClusterDeploymentService clusterDeploymentService;
    private final MembershipEntitlementRepository membershipEntitlementRepository;
    private final HostedUploadUsageRepository hostedUploadUsageRepository;

    public static String currentYearMonthUtc() {
        return YearMonth.now(ZoneOffset.UTC).toString();
    }

    public boolean isHostedUploadEnabled() {
        return clusterDeploymentService.isOverseasDeployment();
    }

    public OverseasMembershipTier effectiveTier(Long userId) {
        return membershipEntitlementRepository.findByUserId(userId)
                .map(this::effectiveTierFromEntitlement)
                .orElse(OverseasMembershipTier.FREE);
    }

    public OverseasMembershipTier effectiveTierFromEntitlement(MembershipEntitlement e) {
        if (e.getSubscriptionExpiresAt() != null && Instant.now().isAfter(e.getSubscriptionExpiresAt())) {
            return OverseasMembershipTier.FREE;
        }
        try {
            return OverseasMembershipTier.fromCode(e.getTierCode());
        } catch (IllegalArgumentException ex) {
            return OverseasMembershipTier.FREE;
        }
    }

    public long quotaBytes(Long userId) {
        return effectiveTier(userId).getMonthlyUploadQuotaBytes();
    }

    public long usedBytes(Long userId, String yearMonth) {
        return hostedUploadUsageRepository.findByUserIdAndYearMonth(userId, yearMonth)
                .map(u -> u.getUploadBytes() != null ? u.getUploadBytes() : 0L)
                .orElse(0L);
    }

    /** Throws if this upload would exceed monthly upload quota. */
    public void ensureUploadAllowed(Long userId, long contentLength) {
        if (!clusterDeploymentService.isOverseasDeployment()) {
            return;
        }
        if (contentLength <= 0) {
            throw new IllegalArgumentException("contentLength required for hosted upload");
        }
        String ym = currentYearMonthUtc();
        long quota = quotaBytes(userId);
        long used = usedBytes(userId, ym);
        if (used + contentLength > quota) {
            throw new IllegalArgumentException("Hosted upload quota exceeded for this month");
        }
    }

    @Transactional
    public void recordUploadBytes(Long userId, long contentLength) {
        if (!clusterDeploymentService.isOverseasDeployment() || contentLength <= 0) {
            return;
        }
        String ym = currentYearMonthUtc();
        var row = hostedUploadUsageRepository.findByUserIdAndYearMonth(userId, ym)
                .orElseGet(() -> {
                    dev.ultrasend.backend.entity.HostedUploadUsage u = new dev.ultrasend.backend.entity.HostedUploadUsage();
                    u.setUserId(userId);
                    u.setYearMonth(ym);
                    u.setUploadBytes(0L);
                    return u;
                });
        long prev = row.getUploadBytes() != null ? row.getUploadBytes() : 0L;
        row.setUploadBytes(prev + contentLength);
        hostedUploadUsageRepository.save(row);
    }
}
