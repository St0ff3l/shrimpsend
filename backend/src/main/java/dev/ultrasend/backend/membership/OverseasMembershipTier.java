package dev.ultrasend.backend.membership;

import java.util.Arrays;

/**
 * ShrimpSend overseas tiers (prod-overseas). Stored in {@code membership_entitlements.tier_code}.
 * Not mixed with domestic {@link MembershipTier} MINI/PRO in the same deployment DB.
 */
public enum OverseasMembershipTier {
    FREE("FREE", "Free", 3, 0L),
    PLUS("PLUS", "Plus", 10, 80L * 1024 * 1024 * 1024),
    PRO("PRO", "Pro", 20, 250L * 1024 * 1024 * 1024),
    ULTRA("ULTRA", "Ultra", 50, 800L * 1024 * 1024 * 1024);

    /** Monthly upload quota for built-in R2; Free tier 1 GiB. */
    private static final long FREE_UPLOAD_QUOTA = 1024L * 1024 * 1024;

    private final String code;
    private final String displayName;
    private final int deviceLimit;
    /** Bytes per calendar month (upload only). */
    private final long monthlyUploadQuotaBytes;

    OverseasMembershipTier(String code, String displayName, int deviceLimit, long monthlyUploadQuotaBytes) {
        this.code = code;
        this.displayName = displayName;
        this.deviceLimit = deviceLimit;
        this.monthlyUploadQuotaBytes = monthlyUploadQuotaBytes;
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

    public long getMonthlyUploadQuotaBytes() {
        return this == FREE ? FREE_UPLOAD_QUOTA : monthlyUploadQuotaBytes;
    }

    public int getRank() {
        return ordinal();
    }

    public boolean isUpgradableTo(OverseasMembershipTier target) {
        return target.getRank() > this.getRank();
    }

    public static OverseasMembershipTier fromCode(String code) {
        return Arrays.stream(values())
                .filter(v -> v.code.equalsIgnoreCase(code))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("无效海外会员档位: " + code));
    }

    public static boolean isValidCode(String code) {
        return Arrays.stream(values()).anyMatch(v -> v.code.equalsIgnoreCase(code));
    }
}
