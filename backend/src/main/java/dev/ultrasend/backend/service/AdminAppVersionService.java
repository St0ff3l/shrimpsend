package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.AdminAppVersionResponse;
import dev.ultrasend.backend.dto.CreateAppVersionRequest;
import dev.ultrasend.backend.dto.UpdateAppVersionRequest;
import dev.ultrasend.backend.entity.AppVersion;
import dev.ultrasend.backend.repository.AppVersionRepository;
import dev.ultrasend.backend.util.PublicDownloadUrlValidator;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminAppVersionService {

    private final AppVersionRepository appVersionRepository;

    public List<AdminAppVersionResponse> listAll() {
        return appVersionRepository.findAllByOrderByBuildNumberDesc().stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public AdminAppVersionResponse create(CreateAppVersionRequest req) {
        if (appVersionRepository.findByBuildNumber(req.getBuildNumber()).isPresent()) {
            throw new IllegalArgumentException("该 build_number 已存在");
        }
        boolean enabled = req.getEnabled() != null ? req.getEnabled() : true;
        boolean webPublished = Boolean.TRUE.equals(req.getWebPublished());
        AppVersion e = AppVersion.builder()
                .version(req.getVersion().trim())
                .buildNumber(req.getBuildNumber())
                .downloadUrl(blankToNull(req.getDownloadUrl()))
                .releaseNotes(blankToNull(req.getReleaseNotes()))
                .iosStoreUrl(blankToNull(req.getIosStoreUrl()))
                .desktopWindowsZipUrl(blankToNull(req.getDesktopWindowsZipUrl()))
                .desktopMacosZipUrl(blankToNull(req.getDesktopMacosZipUrl()))
                .desktopLinuxZipUrl(blankToNull(req.getDesktopLinuxZipUrl()))
                .desktopWindowsZipBytes(req.getDesktopWindowsZipBytes())
                .desktopMacosZipBytes(req.getDesktopMacosZipBytes())
                .desktopLinuxZipBytes(req.getDesktopLinuxZipBytes())
                .enabled(enabled)
                .webPublished(false)
                .build();
        applyPublicUrls(e, req);
        AppVersion saved = appVersionRepository.save(e);
        if (webPublished) {
            clearOtherWebPublished(saved.getId());
            saved.setWebPublished(true);
            saved = appVersionRepository.save(saved);
        }
        return toResponse(saved);
    }

    @Transactional
    public AdminAppVersionResponse update(long id, UpdateAppVersionRequest req) {
        AppVersion e = appVersionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("版本不存在"));
        if (req.getVersion() != null) {
            if (req.getVersion().isBlank()) {
                throw new IllegalArgumentException("version 不能为空");
            }
            e.setVersion(req.getVersion().trim());
        }
        if (req.getBuildNumber() != null) {
            if (req.getBuildNumber() <= 0) {
                throw new IllegalArgumentException("buildNumber 必须为正整数");
            }
            appVersionRepository.findByBuildNumber(req.getBuildNumber())
                    .filter(other -> !other.getId().equals(e.getId()))
                    .ifPresent(x -> {
                        throw new IllegalArgumentException("该 build_number 已被其他记录使用");
                    });
            e.setBuildNumber(req.getBuildNumber());
        }
        if (req.getDownloadUrl() != null) {
            e.setDownloadUrl(blankToNull(req.getDownloadUrl()));
        }
        if (req.getReleaseNotes() != null) {
            e.setReleaseNotes(blankToNull(req.getReleaseNotes()));
        }
        if (req.getIosStoreUrl() != null) {
            e.setIosStoreUrl(blankToNull(req.getIosStoreUrl()));
        }
        if (req.getDesktopWindowsZipUrl() != null) {
            e.setDesktopWindowsZipUrl(blankToNull(req.getDesktopWindowsZipUrl()));
        }
        if (req.getDesktopMacosZipUrl() != null) {
            e.setDesktopMacosZipUrl(blankToNull(req.getDesktopMacosZipUrl()));
        }
        if (req.getDesktopLinuxZipUrl() != null) {
            e.setDesktopLinuxZipUrl(blankToNull(req.getDesktopLinuxZipUrl()));
        }
        if (req.getDesktopWindowsZipBytes() != null) {
            e.setDesktopWindowsZipBytes(req.getDesktopWindowsZipBytes());
        }
        if (req.getDesktopMacosZipBytes() != null) {
            e.setDesktopMacosZipBytes(req.getDesktopMacosZipBytes());
        }
        if (req.getDesktopLinuxZipBytes() != null) {
            e.setDesktopLinuxZipBytes(req.getDesktopLinuxZipBytes());
        }
        if (req.getEnabled() != null) {
            e.setEnabled(req.getEnabled());
        }
        applyPublicUrls(e, req);
        if (req.getWebPublished() != null) {
            if (Boolean.TRUE.equals(req.getWebPublished())) {
                clearOtherWebPublished(e.getId());
                e.setWebPublished(true);
            } else {
                e.setWebPublished(false);
            }
        }
        return toResponse(appVersionRepository.save(e));
    }

    @Transactional
    public AdminAppVersionResponse publishWeb(long id) {
        AppVersion e = appVersionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("版本不存在"));
        clearOtherWebPublished(e.getId());
        e.setWebPublished(true);
        return toResponse(appVersionRepository.save(e));
    }

    @Transactional
    public void delete(long id) {
        AppVersion e = appVersionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("版本不存在"));
        appVersionRepository.delete(e);
    }

    private void clearOtherWebPublished(long exceptId) {
        for (AppVersion other : appVersionRepository.findAll()) {
            if (!other.getId().equals(exceptId) && Boolean.TRUE.equals(other.getWebPublished())) {
                other.setWebPublished(false);
                appVersionRepository.save(other);
            }
        }
    }

    private static void applyPublicUrls(AppVersion e, CreateAppVersionRequest req) {
        if (req.getPublicMacUrlMainland() != null) {
            e.setPublicMacUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicMacUrlMainland()));
        }
        if (req.getPublicWinUrlMainland() != null) {
            e.setPublicWinUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicWinUrlMainland()));
        }
        if (req.getPublicApkUrlMainland() != null) {
            e.setPublicApkUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicApkUrlMainland()));
        }
        if (req.getPublicIosStoreUrlMainland() != null) {
            e.setPublicIosStoreUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicIosStoreUrlMainland()));
        }
        if (req.getPublicMacUrlOverseas() != null) {
            e.setPublicMacUrlOverseas(PublicDownloadUrlValidator.normalizeOptional(req.getPublicMacUrlOverseas()));
        }
        if (req.getPublicWinUrlOverseas() != null) {
            e.setPublicWinUrlOverseas(PublicDownloadUrlValidator.normalizeOptional(req.getPublicWinUrlOverseas()));
        }
        if (req.getPublicGooglePlayUrlOverseas() != null) {
            e.setPublicGooglePlayUrlOverseas(
                    PublicDownloadUrlValidator.normalizeOptional(req.getPublicGooglePlayUrlOverseas()));
        }
        if (req.getPublicAppStoreUrlOverseas() != null) {
            e.setPublicAppStoreUrlOverseas(
                    PublicDownloadUrlValidator.normalizeOptional(req.getPublicAppStoreUrlOverseas()));
        }
        if (req.getPublicApkUrlOverseas() != null) {
            e.setPublicApkUrlOverseas(PublicDownloadUrlValidator.normalizeOptional(req.getPublicApkUrlOverseas()));
        }
    }

    private static void applyPublicUrls(AppVersion e, UpdateAppVersionRequest req) {
        if (req.getPublicMacUrlMainland() != null) {
            e.setPublicMacUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicMacUrlMainland()));
        }
        if (req.getPublicWinUrlMainland() != null) {
            e.setPublicWinUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicWinUrlMainland()));
        }
        if (req.getPublicApkUrlMainland() != null) {
            e.setPublicApkUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicApkUrlMainland()));
        }
        if (req.getPublicIosStoreUrlMainland() != null) {
            e.setPublicIosStoreUrlMainland(PublicDownloadUrlValidator.normalizeOptional(req.getPublicIosStoreUrlMainland()));
        }
        if (req.getPublicMacUrlOverseas() != null) {
            e.setPublicMacUrlOverseas(PublicDownloadUrlValidator.normalizeOptional(req.getPublicMacUrlOverseas()));
        }
        if (req.getPublicWinUrlOverseas() != null) {
            e.setPublicWinUrlOverseas(PublicDownloadUrlValidator.normalizeOptional(req.getPublicWinUrlOverseas()));
        }
        if (req.getPublicGooglePlayUrlOverseas() != null) {
            e.setPublicGooglePlayUrlOverseas(
                    PublicDownloadUrlValidator.normalizeOptional(req.getPublicGooglePlayUrlOverseas()));
        }
        if (req.getPublicAppStoreUrlOverseas() != null) {
            e.setPublicAppStoreUrlOverseas(
                    PublicDownloadUrlValidator.normalizeOptional(req.getPublicAppStoreUrlOverseas()));
        }
        if (req.getPublicApkUrlOverseas() != null) {
            e.setPublicApkUrlOverseas(PublicDownloadUrlValidator.normalizeOptional(req.getPublicApkUrlOverseas()));
        }
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return s.trim();
    }

    private static boolean isNonBlank(String s) {
        return s != null && !s.isBlank();
    }

    private AdminAppVersionResponse toResponse(AppVersion e) {
        String releasedAt = e.getCreatedAt() != null ? e.getCreatedAt().toString() : null;
        boolean mainlandPublic = isNonBlank(e.getPublicMacUrlMainland())
                || isNonBlank(e.getPublicWinUrlMainland())
                || isNonBlank(e.getPublicApkUrlMainland())
                || isNonBlank(e.getPublicIosStoreUrlMainland());
        boolean overseasPlay = isNonBlank(e.getPublicGooglePlayUrlOverseas());
        boolean overseasAppStore = isNonBlank(e.getPublicAppStoreUrlOverseas());
        boolean overseasPublic = isNonBlank(e.getPublicMacUrlOverseas())
                || isNonBlank(e.getPublicWinUrlOverseas())
                || isNonBlank(e.getPublicApkUrlOverseas())
                || overseasPlay
                || overseasAppStore;
        return AdminAppVersionResponse.builder()
                .id(e.getId())
                .version(e.getVersion())
                .buildNumber(e.getBuildNumber())
                .downloadUrl(e.getDownloadUrl() != null ? e.getDownloadUrl() : "")
                .releaseNotes(e.getReleaseNotes() != null ? e.getReleaseNotes() : "")
                .iosStoreUrl(e.getIosStoreUrl() != null ? e.getIosStoreUrl() : "")
                .desktopWindowsZipUrl(e.getDesktopWindowsZipUrl() != null ? e.getDesktopWindowsZipUrl() : "")
                .desktopMacosZipUrl(e.getDesktopMacosZipUrl() != null ? e.getDesktopMacosZipUrl() : "")
                .desktopLinuxZipUrl(e.getDesktopLinuxZipUrl() != null ? e.getDesktopLinuxZipUrl() : "")
                .desktopWindowsZipBytes(e.getDesktopWindowsZipBytes())
                .desktopMacosZipBytes(e.getDesktopMacosZipBytes())
                .desktopLinuxZipBytes(e.getDesktopLinuxZipBytes())
                .enabled(Boolean.TRUE.equals(e.getEnabled()))
                .webPublished(Boolean.TRUE.equals(e.getWebPublished()))
                .publicMacUrlMainland(orEmpty(e.getPublicMacUrlMainland()))
                .publicWinUrlMainland(orEmpty(e.getPublicWinUrlMainland()))
                .publicApkUrlMainland(orEmpty(e.getPublicApkUrlMainland()))
                .publicIosStoreUrlMainland(orEmpty(e.getPublicIosStoreUrlMainland()))
                .publicMacUrlOverseas(orEmpty(e.getPublicMacUrlOverseas()))
                .publicWinUrlOverseas(orEmpty(e.getPublicWinUrlOverseas()))
                .publicGooglePlayUrlOverseas(orEmpty(e.getPublicGooglePlayUrlOverseas()))
                .publicAppStoreUrlOverseas(orEmpty(e.getPublicAppStoreUrlOverseas()))
                .publicApkUrlOverseas(orEmpty(e.getPublicApkUrlOverseas()))
                .mainlandPublicConfigured(mainlandPublic)
                .overseasPublicConfigured(overseasPublic)
                .overseasPlayConfigured(overseasPlay)
                .overseasAppStoreConfigured(overseasAppStore)
                .releasedAt(releasedAt)
                .build();
    }

    private static String orEmpty(String s) {
        return s != null ? s : "";
    }
}
