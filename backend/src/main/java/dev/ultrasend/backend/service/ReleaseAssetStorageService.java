package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.StorageS3Properties;
import dev.ultrasend.backend.dto.ReleasePresignResponse;
import dev.ultrasend.backend.dto.ReleaseServerUploadResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;

import java.io.IOException;
import java.io.InputStream;
import java.time.Duration;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReleaseAssetStorageService {

    private static final Pattern SAFE_NAME = Pattern.compile("^[a-zA-Z0-9._-]+$");
    private static final Set<String> PLATFORMS = Set.of("apk", "windows", "macos", "linux");

    private final StorageS3Properties properties;

    public ReleasePresignResponse presignPut(String platformRaw, int buildNumber, String fileName,
                                             String contentType) {
        requireConfigured();
        String platform = platformRaw != null ? platformRaw.trim().toLowerCase(Locale.ROOT) : "";
        if (!PLATFORMS.contains(platform)) {
            throw new IllegalArgumentException("platform 必须是 apk、windows、macos、linux 之一");
        }
        if (buildNumber <= 0) {
            throw new IllegalArgumentException("buildNumber 必须为正整数");
        }
        String safeName = sanitizeFileName(fileName);
        String key = "releases/" + platform + "/" + buildNumber + "/" + safeName;

        String region = properties.getRegion() != null ? properties.getRegion() : "ap-guangzhou";
        Duration ttl = Duration.ofSeconds(Math.max(60, properties.getPresignExpireSeconds()));

        S3Presigner presigner = S3Presigner.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(properties.getAccessKeyId(), properties.getSecretAccessKey())))
                .endpointOverride(java.net.URI.create(properties.getEndpoint()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(properties.isPathStyleAccessEnabled())
                        .build())
                .build();

        try {
            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .contentType(contentType != null && !contentType.isBlank()
                            ? contentType
                            : "application/octet-stream")
                    .build();
            PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                    .signatureDuration(ttl)
                    .putObjectRequest(putRequest)
                    .build();
            PresignedPutObjectRequest presigned = presigner.presignPutObject(presignRequest);
            String uploadUrl = presigned.url().toString();
            String publicUrl = buildPublicUrl(key);
            log.info("release presign platform={} build={} key={}", platform, buildNumber, key);
            return ReleasePresignResponse.builder()
                    .uploadUrl(uploadUrl)
                    .key(key)
                    .publicUrl(publicUrl)
                    .build();
        } finally {
            presigner.close();
        }
    }

    /**
     * 浏览器先把文件传到本服务，再由服务端 PUT 到 COS，可避免浏览器直连 COS 的 CORS 限制。
     */
    public ReleaseServerUploadResponse uploadViaServer(MultipartFile multipart, String platformRaw,
                                                       int buildNumber, String fileNameOverride) throws IOException {
        requireConfigured();
        if (multipart == null || multipart.isEmpty()) {
            throw new IllegalArgumentException("文件不能为空");
        }
        String platform = platformRaw != null ? platformRaw.trim().toLowerCase(Locale.ROOT) : "";
        if (!PLATFORMS.contains(platform)) {
            throw new IllegalArgumentException("platform 必须是 apk、windows、macos、linux 之一");
        }
        if (buildNumber <= 0) {
            throw new IllegalArgumentException("buildNumber 必须为正整数");
        }
        String rawName = fileNameOverride != null && !fileNameOverride.isBlank()
                ? fileNameOverride
                : multipart.getOriginalFilename();
        String safeName = sanitizeFileName(rawName);
        String key = "releases/" + platform + "/" + buildNumber + "/" + safeName;

        String ct = multipart.getContentType();
        if (ct == null || ct.isBlank()) {
            ct = "application/octet-stream";
        }
        long size = multipart.getSize();
        if (size < 0) {
            throw new IllegalArgumentException("无法读取文件大小");
        }

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(properties.getBucket())
                .key(key)
                .contentType(ct)
                .contentLength(size)
                .build();

        try (S3Client client = buildS3Client(); InputStream in = multipart.getInputStream()) {
            client.putObject(putRequest, RequestBody.fromInputStream(in, size));
        }
        log.info("release server upload ok platform={} build={} key={} bytes={}", platform, buildNumber, key, size);
        return ReleaseServerUploadResponse.builder()
                .key(key)
                .publicUrl(buildPublicUrl(key))
                .sizeBytes(size)
                .build();
    }

    private S3Client buildS3Client() {
        String region = properties.getRegion() != null ? properties.getRegion() : "ap-guangzhou";
        return S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(properties.getAccessKeyId(), properties.getSecretAccessKey())))
                .endpointOverride(java.net.URI.create(properties.getEndpoint()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(properties.isPathStyleAccessEnabled())
                        .build())
                .build();
    }

    private void requireConfigured() {
        if (properties.getEndpoint() == null || properties.getEndpoint().isBlank()
                || properties.getAccessKeyId() == null || properties.getAccessKeyId().isBlank()
                || properties.getSecretAccessKey() == null || properties.getSecretAccessKey().isBlank()
                || properties.getBucket() == null || properties.getBucket().isBlank()) {
            throw new IllegalArgumentException("发行对象存储未配置（storage.s3.*）");
        }
        if (properties.getPublicHost() == null || properties.getPublicHost().isBlank()) {
            throw new IllegalArgumentException("发行对象存储未配置 public-host（storage.s3.public-host）");
        }
    }

    private static String sanitizeFileName(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            throw new IllegalArgumentException("fileName 不能为空");
        }
        String base = fileName.trim();
        int slash = Math.max(base.lastIndexOf('/'), base.lastIndexOf('\\'));
        if (slash >= 0 && slash < base.length() - 1) {
            base = base.substring(slash + 1);
        }
        if (base.isEmpty()) {
            throw new IllegalArgumentException("fileName 无效");
        }
        if (!SAFE_NAME.matcher(base).matches()) {
            throw new IllegalArgumentException("文件名仅允许字母、数字、点、下划线、短横线");
        }
        return base;
    }

    private String buildPublicUrl(String key) {
        String base = properties.getPublicHost().trim().replaceAll("/+$", "");
        return base + "/" + key;
    }
}
