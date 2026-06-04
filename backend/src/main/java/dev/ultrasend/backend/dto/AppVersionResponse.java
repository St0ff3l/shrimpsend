package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AppVersionResponse {

    private String version;
    private int buildNumber;
    private String downloadUrl;
    private String releaseNotes;
    /** Optional: App Store URL for iOS. */
    private String iosStoreUrl;
    /** Optional: release time (ISO-8601), for version history. */
    private String releasedAt;
}
