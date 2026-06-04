package dev.ultrasend.backend.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Tencent COS (S3-compatible) for release artifacts ({@code storage.s3.*}).
 */
@Getter
@Setter
@ConfigurationProperties(prefix = "storage.s3")
public class StorageS3Properties {

    private String endpoint = "";
    private String region = "ap-guangzhou";
    private String accessKeyId = "";
    private String secretAccessKey = "";
    private String bucket = "";
    /** Public download base URL (no trailing slash), e.g. https://bucket.cos.region.myqcloud.com */
    private String publicHost = "";
    private long presignExpireSeconds = 600;
    private boolean pathStyleAccessEnabled = false;
}
