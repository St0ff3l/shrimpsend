package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

@Data
public class CreateAppVersionRequest {

    @NotBlank(message = "version 不能为空")
    private String version;

    @NotNull(message = "buildNumber 不能为空")
    @Positive(message = "buildNumber 必须为正整数")
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
    /** 默认 true */
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
