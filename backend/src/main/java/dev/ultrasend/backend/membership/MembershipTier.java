package dev.ultrasend.backend.membership;

import java.util.Arrays;
import java.util.List;

public enum MembershipTier {
    FREE("FREE", "Free", 3, 0, 0),
    MINI("MINI", "Mini", 6, 3000, 1),
    PRO("PRO", "Pro", 12, 6000, 2);

    private final String code;
    private final String displayName;
    private final int deviceLimit;
    private final int priceCent;
    private final int rank;

    MembershipTier(String code, String displayName, int deviceLimit, int priceCent, int rank) {
        this.code = code;
        this.displayName = displayName;
        this.deviceLimit = deviceLimit;
        this.priceCent = priceCent;
        this.rank = rank;
    }

    public String getCode() {
        return code;
    }

    public String getDisplayName() {
        return displayName;
    }

    public int getDeviceLimit() {
        return deviceLimit;
    }

    public int getPriceCent() {
        return priceCent;
    }

    public int getRank() {
        return rank;
    }

    public static MembershipTier fromCode(String code) {
        return Arrays.stream(values())
                .filter(v -> v.code.equalsIgnoreCase(code))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("无效会员档位: " + code));
    }

    public boolean isUpgradableTo(MembershipTier target) {
        return target.rank > this.rank;
    }

    public static List<MembershipTier> paidTiers() {
        return List.of(MINI, PRO);
    }
}
