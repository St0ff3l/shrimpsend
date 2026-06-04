package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.AppVersionResponse;
import dev.ultrasend.backend.dto.PublicDownloadResponse;
import dev.ultrasend.backend.service.AppVersionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppVersionController {

    private final AppVersionService appVersionService;

    /**
     * Returns the latest enabled version for update check. Use {@code platform} to get the newest
     * version that has a package for that platform. 404 if none match.
     */
    @GetMapping("/version")
    public ResponseEntity<AppVersionResponse> getVersion(
            @RequestParam(value = "platform", required = false) String platform) {
        Optional<AppVersionResponse> result;
        if (platform != null && !platform.isBlank()) {
            result = appVersionService.getLatestForPlatform(platform);
        } else {
            result = appVersionService.getLatest();
        }
        return result.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    /**
     * Returns all enabled versions, newest first (for version history).
     */
    @GetMapping("/versions")
    public ResponseEntity<List<AppVersionResponse>> getVersions() {
        return ResponseEntity.ok(appVersionService.getEnabledHistory());
    }

    /**
     * JSON for {@code flutter_desktop_updater} (windows / macos / linux blocks).
     */
    @GetMapping(value = "/desktop-update.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Map<String, Object>>> getDesktopUpdateJson() {
        return appVersionService.getDesktopUpdateManifest()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Current web-published download links (mainland / overseas), separate from OTA artifacts.
     */
    @GetMapping("/public-download")
    public ResponseEntity<PublicDownloadResponse> getPublicDownload() {
        return ResponseEntity.ok(appVersionService.getPublicDownload());
    }
}
