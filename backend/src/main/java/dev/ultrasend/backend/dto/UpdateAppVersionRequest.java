package dev.ultrasend.backend.dto;

import lombok.Data;

@Data
public class UpdateAppVersionRequest {

    private String version;
    private Integer buildNumber;
    private String downloadUrl;
    private String releaseNotes;
    private String iosStoreUrl;
    private String desktopWindowsZipUrl;
    private String desktopMacosZipUrl;
    private String desktopLinuxZipUrl;
    private Long desktopWindowsZipBytes;
    private Long desktopMacosZipBytes;
    private Long desktopLinuxZipBytes;
    private Boolean enabled;

    private Boolean webPublished;
    private String publicMacUrlMainland;
    private String publicWinUrlMainland;
    private String publicApkUrlMainland;
    private String publicIosStoreUrlMainland;
    private String publicMacUrlOverseas;
    private String publicWinUrlOverseas;
    private String publicGooglePlayUrlOverseas;
    private String publicAppStoreUrlOverseas;
    private String publicApkUrlOverseas;
}
