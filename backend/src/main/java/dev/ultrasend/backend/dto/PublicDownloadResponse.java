package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PublicDownloadResponse {

    private boolean available;
    private String version;
    private int buildNumber;
    private String releaseNotes;
    private PublicDownloadRegionDto mainland;
    private PublicDownloadRegionDto overseas;
}
