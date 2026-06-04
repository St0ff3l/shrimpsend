package dev.ultrasend.backend.util;

public final class PublicDownloadUrlValidator {

    private static final int MAX_LEN = 1024;

    private PublicDownloadUrlValidator() {}

    public static String normalizeOptional(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.length() > MAX_LEN) {
            throw new IllegalArgumentException("URL 长度不能超过 " + MAX_LEN);
        }
        if (!trimmed.startsWith("http://") && !trimmed.startsWith("https://")) {
            throw new IllegalArgumentException("URL 必须以 http:// 或 https:// 开头");
        }
        return trimmed;
    }
}
