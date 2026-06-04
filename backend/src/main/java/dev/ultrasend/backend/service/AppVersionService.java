package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.AppVersionResponse;
import dev.ultrasend.backend.dto.PublicDownloadRegionDto;
import dev.ultrasend.backend.dto.PublicDownloadResponse;
import dev.ultrasend.backend.entity.AppVersion;
import dev.ultrasend.backend.repository.AppVersionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppVersionService {

    private static final Set<String> SUPPORTED_PLATFORMS = Set.of(
            "android", "ios", "windows", "macos", "linux");

    private final AppVersionRepository appVersionRepository;

    /**
     * Returns the latest enabled version (for update check).
     * Prefer {@link #getLatestForPlatform(String)} when the client is platform-specific.
     */
    public Optional<AppVersionResponse> getLatest() {
        return appVersionRepository.findTopByEnabledTrueOrderByBuildNumberDesc()
                .map(this::toResponse);
    }

    /**
     * Latest enabled version that has a package for the given platform (newest build with non-blank artifact URL).
     */
    public Optional<AppVersionResponse> getLatestForPlatform(String platform) {
        String normalized = normalizePlatform(platform);
        return findLatestWithPackageForPlatform(enabledVersionsDesc(), normalized)
                .map(this::toResponse);
    }

    /**
     * Returns all enabled versions, newest first (for version history).
     */
    public List<AppVersionResponse> getEnabledHistory() {
        return enabledVersionsDesc().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Manifest for {@code flutter_desktop_updater}: keys {@code windows}, {@code macos}, {@code linux}.
     * Each platform block uses the newest enabled version that has a ZIP for that platform (may differ per key).
     */
    public PublicDownloadResponse getPublicDownload() {
        return appVersionRepository.findByWebPublishedTrue()
                .map(this::toPublicDownloadResponse)
                .orElseGet(() -> PublicDownloadResponse.builder()
                        .available(false)
                        .version("")
                        .buildNumber(0)
                        .releaseNotes("")
                        .mainland(emptyRegion())
                        .overseas(emptyRegion())
                        .build());
    }

    private PublicDownloadResponse toPublicDownloadResponse(AppVersion e) {
        return PublicDownloadResponse.builder()
                .available(true)
                .version(e.getVersion())
                .buildNumber(e.getBuildNumber())
                .releaseNotes(e.getReleaseNotes() != null ? e.getReleaseNotes() : "")
                .mainland(PublicDownloadRegionDto.builder()
                        .macUrl(orEmpty(e.getPublicMacUrlMainland()))
                        .winUrl(orEmpty(e.getPublicWinUrlMainland()))
                        .apkUrl(orEmpty(e.getPublicApkUrlMainland()))
                        .iosStoreUrl(orEmpty(e.getPublicIosStoreUrlMainland()))
                        .googlePlayUrl("")
                        .appStoreUrl("")
                        .build())
                .overseas(PublicDownloadRegionDto.builder()
                        .macUrl(orEmpty(e.getPublicMacUrlOverseas()))
                        .winUrl(orEmpty(e.getPublicWinUrlOverseas()))
                        .apkUrl(orEmpty(e.getPublicApkUrlOverseas()))
                        .googlePlayUrl(orEmpty(e.getPublicGooglePlayUrlOverseas()))
                        .appStoreUrl(orEmpty(e.getPublicAppStoreUrlOverseas()))
                        .iosStoreUrl("")
                        .build())
                .build();
    }

    private static PublicDownloadRegionDto emptyRegion() {
        return PublicDownloadRegionDto.builder()
                .macUrl("")
                .winUrl("")
                .apkUrl("")
                .iosStoreUrl("")
                .googlePlayUrl("")
                .appStoreUrl("")
                .build();
    }

    private static String orEmpty(String s) {
        return s != null ? s.trim() : "";
    }

    public Optional<Map<String, Map<String, Object>>> getDesktopUpdateManifest() {
        List<AppVersion> versions = enabledVersionsDesc();
        if (versions.isEmpty()) {
            return Optional.empty();
        }
        Map<String, Map<String, Object>> root = new LinkedHashMap<>();
        root.put("windows", desktopBlockForPlatform(versions, "windows"));
        root.put("macos", desktopBlockForPlatform(versions, "macos"));
        root.put("linux", desktopBlockForPlatform(versions, "linux"));
        return Optional.of(root);
    }

    private List<AppVersion> enabledVersionsDesc() {
        return appVersionRepository.findAllByEnabledTrueOrderByBuildNumberDesc();
    }

    private Optional<AppVersion> findLatestWithPackageForPlatform(List<AppVersion> versions, String platform) {
        return versions.stream()
                .filter(v -> hasPackageForPlatform(v, platform))
                .findFirst();
    }

    private Map<String, Object> desktopBlockForPlatform(List<AppVersion> versions, String platform) {
        return findLatestWithPackageForPlatform(versions, platform)
                .map(v -> platformDesktopEntry(zipUrlForPlatform(v, platform), zipBytesForPlatform(v, platform), v))
                .orElseGet(this::emptyDesktopBlock);
    }

    private static String normalizePlatform(String platform) {
        if (platform == null || platform.isBlank()) {
            throw new IllegalArgumentException("platform 不能为空");
        }
        String normalized = platform.trim().toLowerCase();
        if (!SUPPORTED_PLATFORMS.contains(normalized)) {
            throw new IllegalArgumentException(
                    "不支持的 platform: " + platform + "，可选: android, ios, windows, macos, linux");
        }
        return normalized;
    }

    private static boolean hasPackageForPlatform(AppVersion v, String platform) {
        return !zipUrlForPlatform(v, platform).isBlank();
    }

    private static String zipUrlForPlatform(AppVersion v, String platform) {
        String url = switch (platform) {
            case "android" -> v.getDownloadUrl();
            case "ios" -> v.getIosStoreUrl();
            case "windows" -> v.getDesktopWindowsZipUrl();
            case "macos" -> v.getDesktopMacosZipUrl();
            case "linux" -> v.getDesktopLinuxZipUrl();
            default -> null;
        };
        return url != null ? url.trim() : "";
    }

    private static Long zipBytesForPlatform(AppVersion v, String platform) {
        return switch (platform) {
            case "windows" -> v.getDesktopWindowsZipBytes();
            case "macos" -> v.getDesktopMacosZipBytes();
            case "linux" -> v.getDesktopLinuxZipBytes();
            default -> null;
        };
    }

    private Map<String, Object> emptyDesktopBlock() {
        Map<String, Object> block = new LinkedHashMap<>();
        block.put("version", "0.0.0");
        block.put("build_number", "0");
        block.put("download_url", "");
        block.put("file_size", 0);
        block.put("release_notes", "");
        return block;
    }

    private Map<String, Object> platformDesktopEntry(String zipUrl, Long zipBytes, AppVersion v) {
        Map<String, Object> block = new LinkedHashMap<>();
        block.put("version", v.getVersion());
        block.put("build_number", String.valueOf(v.getBuildNumber()));
        block.put("download_url", zipUrl);
        block.put("file_size", toManifestFileSize(zipBytes));
        block.put("release_notes", v.getReleaseNotes() != null ? v.getReleaseNotes() : "");
        return block;
    }

    /** JSON field is int in flutter_desktop_updater; cap at {@link Integer#MAX_VALUE}. */
    private static int toManifestFileSize(Long zipBytes) {
        if (zipBytes == null || zipBytes <= 0) {
            return 0;
        }
        return zipBytes > Integer.MAX_VALUE ? Integer.MAX_VALUE : zipBytes.intValue();
    }

    private AppVersionResponse toResponse(AppVersion e) {
        String releasedAt = e.getCreatedAt() != null ? e.getCreatedAt().toString() : null;
        return AppVersionResponse.builder()
                .version(e.getVersion())
                .buildNumber(e.getBuildNumber())
                .downloadUrl(e.getDownloadUrl() != null ? e.getDownloadUrl() : "")
                .releaseNotes(e.getReleaseNotes() != null ? e.getReleaseNotes() : "")
                .iosStoreUrl(e.getIosStoreUrl() != null ? e.getIosStoreUrl() : "")
                .releasedAt(releasedAt)
                .build();
    }
}
