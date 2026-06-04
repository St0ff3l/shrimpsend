package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class S3ConfigRequest {

    @NotBlank
    private String endpoint;

    private String region;

    @NotBlank
    private String bucket;

    @NotBlank
    private String accessKeyId;

    /** 留空则保存时不修改已有 secret。 */
    private String secretAccessKey;

    /** null 时按 true（Path-style）保存，与历史客户端行为一致。 */
    private Boolean pathStyleAccessEnabled;
}
