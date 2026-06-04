package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "app_version", uniqueConstraints = @UniqueConstraint(columnNames = "build_number"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AppVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 32)
    private String version;

    @Column(name = "build_number", nullable = false, unique = true)
    private Integer buildNumber;

    @Column(name = "download_url", length = 1024)
    private String downloadUrl;

    @Column(name = "release_notes", columnDefinition = "TEXT")
    private String releaseNotes;

    @Column(name = "ios_store_url", length = 1024)
    private String iosStoreUrl;

    @Column(name = "desktop_windows_zip_url", length = 1024)
    private String desktopWindowsZipUrl;

    @Column(name = "desktop_macos_zip_url", length = 1024)
    private String desktopMacosZipUrl;

    @Column(name = "desktop_linux_zip_url", length = 1024)
    private String desktopLinuxZipUrl;

    @Column(name = "desktop_windows_zip_bytes")
    private Long desktopWindowsZipBytes;

    @Column(name = "desktop_macos_zip_bytes")
    private Long desktopMacosZipBytes;

    @Column(name = "desktop_linux_zip_bytes")
    private Long desktopLinuxZipBytes;

    @Column(nullable = false)
    @Builder.Default
    private Boolean enabled = true;

    @Column(name = "web_published", nullable = false)
    @Builder.Default
    private Boolean webPublished = false;

    @Column(name = "public_mac_url_mainland", length = 1024)
    private String publicMacUrlMainland;

    @Column(name = "public_win_url_mainland", length = 1024)
    private String publicWinUrlMainland;

    @Column(name = "public_apk_url_mainland", length = 1024)
    private String publicApkUrlMainland;

    @Column(name = "public_ios_store_url_mainland", length = 1024)
    private String publicIosStoreUrlMainland;

    @Column(name = "public_mac_url_overseas", length = 1024)
    private String publicMacUrlOverseas;

    @Column(name = "public_win_url_overseas", length = 1024)
    private String publicWinUrlOverseas;

    @Column(name = "public_google_play_url_overseas", length = 1024)
    private String publicGooglePlayUrlOverseas;

    @Column(name = "public_app_store_url_overseas", length = 1024)
    private String publicAppStoreUrlOverseas;

    @Column(name = "public_apk_url_overseas", length = 1024)
    private String publicApkUrlOverseas;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
