package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.HostedS3Properties;
import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.repository.S3ConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.*;

import java.io.IOException;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Platform-hosted bucket (e.g. R2). Used when overseas deployment and user has no BYO S3 config.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class HostedS3Service {

    private final HostedS3Properties properties;
    private final ClusterDeploymentService clusterDeploymentService;
    private final HostedQuotaService hostedQuotaService;
    private final S3ConfigRepository s3ConfigRepository;

    public boolean isActive() {
        return clusterDeploymentService.isOverseasDeployment()
                && properties.isEnabled()
                && properties.getBucket() != null && !properties.getBucket().isBlank();
    }

    public boolean useHostedForUser(Long userId) {
        if (!isActive()) {
            return false;
        }
        var byo = s3ConfigRepository.findByUserId(userId);
        if (byo.isEmpty()) {
            return true;
        }
        // BYO 已保存但用户主动切到了内置：依然走 hosted 桶
        return Boolean.TRUE.equals(byo.get().getPrefersHosted());
    }

    /**
     * 校验内置桶的可达性（HeadBucket）。失败时抛 {@link IllegalArgumentException}，
     * 文案与 {@link S3Service#testConfig(Long)} 中 BYO 桶的失败保持一致。
     */
    public void verifyConnectivity() {
        if (!isActive()) {
            throw new IllegalArgumentException("Hosted storage not configured");
        }
        try (S3Client client = buildClient()) {
            client.headBucket(HeadBucketRequest.builder().bucket(properties.getBucket()).build());
            log.info("hosted s3 verifyConnectivity ok bucket={}", properties.getBucket());
        } catch (S3Exception e) {
            String detail = e.awsErrorDetails() != null && e.awsErrorDetails().errorMessage() != null
                    ? e.awsErrorDetails().errorMessage()
                    : (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName());
            log.warn("hosted s3 verifyConnectivity failed httpStatus={} error={}", e.statusCode(), detail);
            throw new IllegalArgumentException("S3 连接失败: " + detail);
        } catch (software.amazon.awssdk.core.exception.SdkClientException e) {
            log.warn("hosted s3 verifyConnectivity sdk client error", e);
            throw new IllegalArgumentException("S3 连接失败: "
                    + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()));
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            log.warn("hosted s3 verifyConnectivity unexpected", e);
            throw new IllegalArgumentException("S3 连接失败: "
                    + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()));
        }
    }

    public PresignUploadResponse presignUpload(Long userId, String fileName, String contentType, long contentLength) {
        requireConfigured();
        hostedQuotaService.ensureUploadAllowed(userId, contentLength);
        String key = "hosted/" + userId + "/" + UUID.randomUUID() + "/" + fileName;
        log.debug("hosted presignUpload userId={} key={} bytes={}", userId, key, contentLength);

        S3Presigner presigner = buildPresigner();
        try {
            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .contentType(contentType != null ? contentType : "application/octet-stream")
                    .contentLength(contentLength)
                    .build();
            PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofHours(1))
                    .putObjectRequest(putRequest)
                    .build();
            PresignedPutObjectRequest presigned = presigner.presignPutObject(presignRequest);
            hostedQuotaService.recordUploadBytes(userId, contentLength);
            return PresignUploadResponse.builder()
                    .uploadUrl(presigned.url().toString())
                    .key(key)
                    .build();
        } finally {
            presigner.close();
        }
    }

    public String presignDownload(Long userId, String key) {
        requireConfigured();
        if (!key.startsWith("hosted/" + userId + "/")) {
            throw new IllegalArgumentException("Invalid key");
        }
        long expireSec = Math.min(properties.getDownloadPresignExpireSeconds(), 259200L);
        S3Presigner presigner = buildPresigner();
        try {
            GetObjectRequest getRequest = GetObjectRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .build();
            GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofSeconds(expireSec))
                    .getObjectRequest(getRequest)
                    .build();
            return presigner.presignGetObject(presignRequest).url().toString();
        } finally {
            presigner.close();
        }
    }

    public MultipartInitiateResponse initiateMultipart(Long userId, String fileName, String contentType, long totalSize) {
        requireConfigured();
        hostedQuotaService.ensureUploadAllowed(userId, totalSize);
        String key = "hosted/" + userId + "/" + UUID.randomUUID() + "/" + fileName;
        try (S3Client client = buildClient()) {
            CreateMultipartUploadResponse resp = client.createMultipartUpload(CreateMultipartUploadRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .contentType(contentType != null ? contentType : "application/octet-stream")
                    .build());
            return MultipartInitiateResponse.builder()
                    .uploadId(resp.uploadId())
                    .key(key)
                    .build();
        }
    }

    public String presignUploadPart(Long userId, String uploadId, String key, int partNumber) {
        requireConfigured();
        validateKey(userId, key);
        S3Presigner presigner = buildPresigner();
        try {
            UploadPartRequest partReq = UploadPartRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .uploadId(uploadId)
                    .partNumber(partNumber)
                    .build();
            UploadPartPresignRequest presignReq = UploadPartPresignRequest.builder()
                    .signatureDuration(Duration.ofHours(1))
                    .uploadPartRequest(partReq)
                    .build();
            return presigner.presignUploadPart(presignReq).url().toString();
        } finally {
            presigner.close();
        }
    }

    public void completeMultipart(Long userId, String uploadId, String key,
                                  List<MultipartCompleteRequest.PartInfo> parts) {
        requireConfigured();
        validateKey(userId, key);
        List<CompletedPart> completedParts = parts.stream()
                .map(p -> CompletedPart.builder()
                        .partNumber(p.getPartNumber())
                        .eTag(p.getETag())
                        .build())
                .collect(Collectors.toList());
        try (S3Client client = buildClient()) {
            client.completeMultipartUpload(CompleteMultipartUploadRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .uploadId(uploadId)
                    .multipartUpload(CompletedMultipartUpload.builder()
                            .parts(completedParts)
                            .build())
                    .build());
        }
        long totalSize = headContentLength(key);
        hostedQuotaService.recordUploadBytes(userId, totalSize);
    }

    public void abortMultipart(Long userId, String uploadId, String key) {
        requireConfigured();
        validateKey(userId, key);
        try (S3Client client = buildClient()) {
            client.abortMultipartUpload(AbortMultipartUploadRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .uploadId(uploadId)
                    .build());
        }
    }

    private long headContentLength(String key) {
        try (S3Client client = buildClient()) {
            HeadObjectResponse h = client.headObject(HeadObjectRequest.builder()
                    .bucket(properties.getBucket())
                    .key(key)
                    .build());
            return h.contentLength() != null ? h.contentLength() : 0L;
        }
    }

    private void validateKey(Long userId, String key) {
        if (!key.startsWith("hosted/" + userId + "/")) {
            throw new IllegalArgumentException("Invalid key");
        }
    }

    private void requireConfigured() {
        if (!isActive()) {
            throw new IllegalArgumentException("Hosted storage not configured");
        }
    }

    private S3Client buildClient() {
        String region = properties.getRegion() != null ? properties.getRegion() : "auto";
        return S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(properties.getAccessKeyId(), properties.getSecretAccessKey())))
                .endpointOverride(java.net.URI.create(properties.getEndpoint()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(true)
                        .build())
                .build();
    }

    private S3Presigner buildPresigner() {
        String region = properties.getRegion() != null ? properties.getRegion() : "auto";
        return S3Presigner.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(properties.getAccessKeyId(), properties.getSecretAccessKey())))
                .endpointOverride(java.net.URI.create(properties.getEndpoint()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(true)
                        .build())
                .build();
    }
}
