package dev.ultrasend.backend.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Platform-hosted object storage (e.g. Cloudflare R2) for ShrimpSend overseas built-in uploads.
 */
@Getter
@Setter
@ConfigurationProperties(prefix = "app.storage.hosted-s3")
public class HostedS3Properties {

    private boolean enabled = false;
    private String endpoint = "";
    private String region = "auto";
    private String accessKeyId = "";
    private String secretAccessKey = "";
    private String bucket = "";
    /** Presigned GET for downloads (seconds). Overseas default 72h. */
    private long downloadPresignExpireSeconds = 259200;
}
