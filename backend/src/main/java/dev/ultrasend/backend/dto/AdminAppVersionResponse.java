package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminAppVersionResponse {

    private Long id;
    private String version;
    private int buildNumber;
    private String downloadUrl;
    private String releaseNotes;
    private String iosStoreUrl;
    private String desktopWindowsZipUrl;
    private String desktopMacosZipUrl;
    private String desktopLinuxZipUrl;
    private Long desktopWindowsZipBytes;
    private Long desktopMacosZipBytes;
    private Long desktopLinuxZipBytes;
    private boolean enabled;
    private boolean webPublished;
    private String publicMacUrlMainland;
    private String publicWinUrlMainland;
    private String publicApkUrlMainland;
    private String publicIosStoreUrlMainland;
    private String publicMacUrlOverseas;
    private String publicWinUrlOverseas;
    private String publicGooglePlayUrlOverseas;
    private String publicAppStoreUrlOverseas;
    private String publicApkUrlOverseas;
    private boolean mainlandPublicConfigured;
    private boolean overseasPublicConfigured;
    private boolean overseasPlayConfigured;
    private boolean overseasAppStoreConfigured;
    private String releasedAt;
}
