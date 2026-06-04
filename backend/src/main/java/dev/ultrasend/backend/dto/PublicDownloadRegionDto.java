package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PublicDownloadRegionDto {

    private String macUrl;
    private String winUrl;
    private String apkUrl;
    private String iosStoreUrl;
    /** Overseas only; empty for mainland in API mapping. */
    private String googlePlayUrl;
    /** Overseas only; empty for mainland in API mapping. */
    private String appStoreUrl;
}
